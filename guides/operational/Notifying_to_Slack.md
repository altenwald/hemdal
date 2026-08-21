# Notifying to Slack and Mattermost

Hemdal includes built-in notifiers for popular collaboration and alerting platforms, including [Slack](https://api.slack.com/messaging/webhooks) and [Mattermost](https://developers.mattermost.com/integrate/webhooks/incoming/).

## Notifier Configuration Fields

Each notifier attached to an alert supports the following fields:

- `module`: The notifier implementation module (e.g. `Hemdal.Notifier.Slack` or `Hemdal.Notifier.Mattermost`, default: `Hemdal.Notifier.Slack`).
- `token`: For Slack, the webhook URL (e.g. `https://hooks.slack.com/services/YOUR_SLACK_WEBHOOK` or `/services/YOUR_SLACK_WEBHOOK`). For Mattermost, the authorization token or webhook path.
- `username`: The username displayed as the sender (default: `"Hemdal"`).
- `log_level`: Level of notifications to deliver:
  - `"debug"`: Delivers all notifications on every state transition and recurring check.
  - `"warn"`: Delivers notifications whenever the status changes (e.g. `:ok` -> `:warn`, `:warn` -> `:error`, `:error` -> `:ok`).
  - `"error"`: Delivers notifications only when transitioning into or out of the `:error` (`broken`) state.
- `metadata`: A map of additional configuration options:
  - `"channel"`: Destination channel override (e.g. `"#alerts"` or `"@username"`).
  - `"icon"`: Custom emoji icon for the bot (e.g. `":rotating_light:"` or `":warning:"`).
  - `"base_url"`: (For Mattermost) The base URL of the Mattermost server (e.g. `"https://mattermost.example.com/api/v4"`).

## Slack Notification Configuration Example

### Using Elixir Environment Backend

```elixir
config :hemdal, Hemdal.Config, [
  [
    id: "aea48656-be08-4576-a2d0-2723458faefd",
    name: "Production Database Check",
    host: [
      id: "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
      module: Hemdal.Host.Local,
      name: "db-primary"
    ],
    command: [
      name: "check_pg_ready",
      type: "line",
      command: "pg_isready -h localhost && echo '[\"OK\", \"PostgreSQL is accepting connections\"]' || echo '[\"FAIL\", \"PostgreSQL is down\"]'"
    ],
    notifiers: [
      [
        module: Hemdal.Notifier.Slack,
        token: "https://hooks.slack.com/services/YOUR_SLACK_WEBHOOK",
        username: "Hemdal Monitor",
        log_level: "warn",
        metadata: %{
          "channel" => "#infrastructure-alerts",
          "icon" => ":fire:"
        }
      ]
    ]
  ]
]
```

### Using JSON Backend

In `alerts.json`:

```json
[
  {
    "id": "aea48656-be08-4576-a2d0-2723458faefd",
    "name": "Production Database Check",
    "host_id": "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
    "command": {
      "name": "check_pg_ready",
      "type": "line",
      "command": "pg_isready -h localhost && echo '[\"OK\", \"PostgreSQL is accepting connections\"]' || echo '[\"FAIL\", \"PostgreSQL is down\"]'"
    },
    "notifiers": [
      {
        "module": "Hemdal.Notifier.Slack",
        "token": "https://hooks.slack.com/services/YOUR_SLACK_WEBHOOK",
        "username": "Hemdal Monitor",
        "log_level": "warn",
        "metadata": {
          "channel": "#infrastructure-alerts",
          "icon": ":fire:"
        }
      }
    ]
  }
]
```

## Mattermost Notification Configuration Example

```elixir
[
  module: Hemdal.Notifier.Mattermost,
  token: "your-mattermost-token-here",
  username: "Hemdal Bot",
  log_level: "warn",
  metadata: %{
    "base_url" => "https://mattermost.yourdomain.com/api/v4",
    "channel" => "monitoring-alerts"
  }
]
```

## Message Formatting and Colors

Notifications sent to Slack and Mattermost include styled rich message attachments:

| Status | Color | Description |
| :--- | :--- | :--- |
| **OK** | `#009900` (Green) | Service recovered or healthy |
| **WARN** | `#FFDA55` (Yellow) | Service started failing (retrying) |
| **FAIL** | `#990000` (Red) | Service confirmed broken |
| **OFF** | `#888888` (Gray) | Alert disabled |
| **UNKNOWN** | `#444444` (Dark Gray) | Unrecognized status |

The attachment includes detailed fields:
- **Host Name**: Name of the target host
- **Command Name**: Name of the executed command
- **Description**: Output message or error details
- **Status**: Current status (`OK`, `WARN`, `FAIL`, `OFF`)
- **Prev. Status**: Previous state before transition
- **Duration**: Duration of failure in seconds
- **Incoming Status**: Raw status from command execution

