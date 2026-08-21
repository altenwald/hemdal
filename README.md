# Hemdal Alerts/Alarms Panel

[![Elixir CI](https://github.com/altenwald/hemdal/actions/workflows/elixir.yml/badge.svg)](https://github.com/altenwald/hemdal/actions/workflows/elixir.yml)
[![Hex.pm Version](https://img.shields.io/hexpm/v/hemdal.svg)](https://hex.pm/packages/hemdal)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/hemdal/)
[![Hex.pm Total Downloads](https://img.shields.io/hexpm/dt/hemdal.svg)](https://hex.pm/packages/hemdal)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://raw.githubusercontent.com/altenwald/hemdal/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/altenwald/hemdal.svg)](https://github.com/altenwald/hemdal/commits/master)
[![Paypal: Donation](https://img.shields.io/badge/paypal-donation-yellow)](https://www.paypal.com/donate/?hosted_button_id=XK6Z5XATN77L2)
[![Patreon: Donation](https://img.shields.io/badge/patreon-donation-yellow)](https://www.patreon.com/altenwald)

**Hemdal** is an extensible alerts and alarms monitoring library for Elixir applications. It proactively monitors local and remote hosts, evaluates health check rules, tracks state transitions, and sends notifications when issues or recoveries occur.

---

## Features

- **Extensible Host Execution (`Hemdal.Host`):**
  - Execute checks locally ([`Hemdal.Host.Local`](https://hexdocs.pm/hemdal/Hemdal.Host.Local.html)) or remotely via SSH/PTY/SFTP with [Trooper](https://github.com/army-cat/trooper).
  - Proactive connections without requiring agent installations on target servers.
  - Worker pooling with dynamic concurrency limits (`max_workers`) and queue draining.
- **Robust State Machine (`Hemdal.Check`):**
  - Manages check lifecycles with configurable check intervals, recheck intervals, and retry thresholds.
  - States: `:normal` (OK), `:failing` (WARN), `:broken` (FAIL), and `:disabled` (OFF).
- **Event Pipeline (`Hemdal.Event`):**
  - Built with [GenStage](https://hex.pm/packages/gen_stage) for reliable event production and consumption.
  - Logging consumer ([`Hemdal.Event.Log`](https://hexdocs.pm/hemdal/Hemdal.Event.Log.html)) and notification dispatcher ([`Hemdal.Event.Notification`](https://hexdocs.pm/hemdal/Hemdal.Event.Notification.html)).
- **Integrated Notifiers (`Hemdal.Notifier`):**
  - Ready-to-use integrations for [Slack](https://hexdocs.pm/hemdal/Hemdal.Notifier.Slack.html) and [Mattermost](https://hexdocs.pm/hemdal/Hemdal.Notifier.Mattermost.html).
  - Easy-to-implement behaviour for custom notification channels (Email, Webhooks, Telegram, PagerDuty, etc.).
- **Flexible Configuration Backends (`Hemdal.Config`):**
  - Read configuration from Elixir Application Environment (`Env`) or JSON files (`Json`).
  - Supports dynamic configuration reloads at runtime via `Hemdal.reload_all/0`.

---

## Installation

Add `hemdal` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hemdal, "~> 1.2"}
  ]
end
```

---

## Quick Example

Configure your hosts and alert checks in `config/config.exs`:

```elixir
import Config

config :hemdal, :config_module, Hemdal.Config.Backend.Env

config :hemdal, Hemdal.Config, [
  [
    id: "disk-space-check",
    name: "Disk Space Check",
    host: [
      id: "localhost-node",
      name: "localhost",
      module: Hemdal.Host.Local,
      max_workers: 2
    ],
    command: [
      name: "check_disk",
      type: "line",
      command: "df -h / | awk 'NR==2 {print $5}'"
    ],
    check_in_sec: 60,
    recheck_in_sec: 10,
    retries: 3,
    notifiers: [
      [
        module: Hemdal.Notifier.Slack,
        token: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
        channel: "#monitoring",
        username: "HemdalBot"
      ]
    ]
  ]
]
```

---

## Documentation

Full documentation and guides are available on [HexDocs](https://hexdocs.pm/hemdal):

- [Getting Started](https://hexdocs.pm/hemdal/getting_started.html)
- [Creating Alerts](https://hexdocs.pm/hemdal/creating_alerts.html)
- [Notifying to Slack](https://hexdocs.pm/hemdal/notifying_to_slack.html)

---

## License

This project is licensed under the terms of the [MIT License](LICENSE).

---

## Contributing & Support

- Open an issue or pull request on [GitHub](https://github.com/altenwald/hemdal).
- Please adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) and review our [Contributing Guidelines](CONTRIBUTING.md).
- If you find Hemdal helpful, consider supporting the project:

[![Donate with PayPal](https://www.paypalobjects.com/en_US/GB/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=XK6Z5XATN77L2)

Enjoy!
