# Creating Alerts

Hemdal allows you to monitor hosts and services by running periodic checks and transitioning through defined states based on the command result.

## Alert Structure

An alert is configured with the following properties:

- `id`: A unique identifier string (e.g. UUID) for the alert process.
- `name`: A human-readable name describing what is being monitored.
- `enabled`: Boolean flag (`true` by default). When `false`, the alert is in `:disabled` state and performs no checks.
- `check_in_sec`: Interval in seconds between checks while in the `:normal` (healthy) state (default: `60`).
- `recheck_in_sec`: Interval in seconds between retries when a check fails (default: `5`).
- `broken_recheck_in_sec`: Interval in seconds between checks once confirmed `:broken` (default: `30`).
- `retries`: Number of consecutive failures in `:failing` state before transitioning to `:broken` (default: `3`).
- `command_args`: A list of string arguments passed to the executed command (default: `[]`).
- `host`: The host configuration on which the command will be executed (see `Hemdal.Config.Host`).
- `command`: The command to execute (see `Hemdal.Config.Command`).
- `notifiers`: A list of notifiers to dispatch notifications to upon state transitions (see `Hemdal.Config.Notifier`).

## State Machine Lifecycle

Each alert runs as an independent state machine with four possible states:

1. **`disabled`**: The alert is inactive. It does not perform checks until re-enabled.
2. **`normal`**: The check succeeds (`OK`). Checked every `check_in_sec` seconds.
3. **`failing`**: The check returned an error or warning (`WARN` / `FAIL` / `UNKNOWN`). Retried every `recheck_in_sec` seconds for up to `retries` times.
4. **`broken`**: The alert failed all retries and is confirmed broken. Checked every `broken_recheck_in_sec` seconds until recovery.

## Configuration Examples

### 1. Elixir Environment Backend (`Hemdal.Config.Backend.Env`)

In your `config/config.exs` or runtime configuration:

```elixir
import Config

config :hemdal, :config_module, Hemdal.Config.Backend.Env

config :hemdal, Hemdal.Config, [
  [
    id: "36c16e85-7221-4021-8d6d-89f38a6d136c",
    name: "Disk Space Check",
    enabled: true,
    check_in_sec: 60,
    recheck_in_sec: 5,
    broken_recheck_in_sec: 30,
    retries: 3,
    host: [
      id: "ec8fff22-41c2-4245-8a7b-5157d40c33a7",
      name: "localhost",
      module: Hemdal.Host.Local,
      max_workers: 2
    ],
    command: [
      name: "check_disk",
      type: "line",
      command: "df -h / | awk 'NR==2 {print $5}' | sed 's/%//' | awk '{if ($1 > 90) print \"[\\\"FAIL\\\", \\\"Disk full: \"$1\"%\\\"]\"; else print \"[\\\"OK\\\", \\\"Disk usage: \"$1\"%\\\"]\"}'",
      decode: true
    ],
    notifiers: [
      [
        module: Hemdal.Notifier.Slack,
        token: "https://hooks.slack.com/services/YOUR_SLACK_WEBHOOK",
        username: "Hemdal Bot",
        log_level: "warn"
      ]
    ]
  ]
]
```

### 2. JSON Backend (`Hemdal.Config.Backend.Json`)

Configure file paths in `config/config.exs`:

```elixir
import Config

config :hemdal, :config_module, Hemdal.Config.Backend.Json

config :hemdal, Hemdal.Config,
  hosts_file: "config/hosts.json",
  alerts_file: "config/alerts.json"
```

In `config/hosts.json`:

```json
[
  {
    "id": "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
    "name": "127.0.0.1",
    "module": "Hemdal.Host.Local",
    "max_workers": 2
  }
]
```

In `config/alerts.json`:

```json
[
  {
    "id": "52d13d6d-f217-4152-965d-cf5f488ceac4",
    "name": "HTTP Health Check",
    "enabled": true,
    "host_id": "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
    "check_in_sec": 30,
    "recheck_in_sec": 5,
    "broken_recheck_in_sec": 15,
    "retries": 2,
    "command": {
      "name": "curl_health",
      "type": "line",
      "command": "curl -s -f http://localhost:4000/health && echo '[\"OK\", \"healthy\"]' || echo '[\"FAIL\", \"unhealthy\"]'"
    }
  }
]
```

## Command Types

- **`line`**: A single command line executed via the host handler.
- **`script`**: A multi-line script written to a temporary file on the host, executed, and cleaned up automatically.
- **`shell`**: An interactive shell session allowing real-time bidirectional data piping.

## Command Output Formats

When `decode: true` (default), Hemdal parses the output as JSON. The command can output:

1. A JSON array: `["OK", "All systems operational"]` or `["FAIL", "High CPU usage"]`
2. A JSON map: `{"status": "OK", "message": "Healthy", "custom_metric": 42}`
3. A JSON string status: `"OK"` or `"FAIL"`

Statuses recognized by Hemdal are `"OK"`, `"WARN"`, `"FAIL"`, and `"UNKNOWN"`.
Exit code `0` maps to `:ok`, exit code `1` maps to `WARN`, and exit code `2` maps to `FAIL`.

## Managing Alerts Programmatically

```elixir
# Retrieve all running alerts and their current statuses
Hemdal.get_all_alerts()

# Reload configuration from backend (starts new alerts, updates existing, and stops deleted ones)
Hemdal.reload_all()

# Manually start a specific alert by ID from backend configuration
Hemdal.start_alert!("36c16e85-7221-4021-8d6d-89f38a6d136c")

# Stop an alert
Hemdal.Check.stop("36c16e85-7221-4021-8d6d-89f38a6d136c")
```

