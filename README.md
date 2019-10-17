# Hemdal Alerts/Alarms Panel

[![Build Status](https://img.shields.io/travis/altenwald/hemdal/master.svg)](https://travis-ci.org/altenwald/hemdal)
[![Codecov](https://img.shields.io/codecov/c/github/altenwald/hemdal.svg)](https://codecov.io/gh/altenwald/hemdal)
[![License: LGPL 2.1](https://img.shields.io/github/license/altenwald/hemdal.svg)](https://raw.githubusercontent.com/altenwald/hemdal/master/COPYING)
[![Paypal: Donation](https://img.shields.io/badge/paypal-donation-yellow)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=RC5F8STDA6AXE)
[![Patreon: Donation](https://img.shields.io/badge/patreon-donation-yellow)](https://www.patreon.com/altenwald)

Panel to show Alerts/Alarms and get notified when an error or recovery happens.

Features:

- Checks are performed through a SSH connection (handled by [Trooper](https://github.com/army-cat/trooper)):
  - SSH user and password configuration.
  - SSH user and certificate (RSA, DSA and ECDSA).
  - SFTP to send scripts commands.
- Alert groups let you create group for your alerts.
- Enable/Disable alerts.
- Reload without stop the system.
- Store configuration for alerts in database (PostgreSQL).
- Web interface refreshed using websockets (real-time).

You can see what is done and what is in progress in our [Trello](https://trello.com/b/07r5YR8Y/hemdal) board.

## Getting started

First, you need to clone the repository. I think Github gives a lot of information about how to do this. Eventually, when a release is available you can download directly the tarball instead of the repository.

To proceed using `git` we can perform these commands:

```
git clone git@github.com:altenwald/hemdal.git
cd hemdal
mix do deps.get, compile
iex -S mix phx.server
```

At this moment, this is the development usage. This way you can check faster if the system is working properly for you.

## What's next?

Documentation is coming soon... in the meantime, you can open an issue to ask whatever, request a feature o report a bug. Also you can provide PR (pull requests) with fixes if you catch some of them, or provide some features.

Don't forget to support us if you find this project interesting enough:

[![Paypal: Donation](https://img.shields.io/badge/paypal-donation-yellow)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=RC5F8STDA6AXE)
[![Patreon: Donation](https://img.shields.io/badge/patreon-donation-yellow)](https://www.patreon.com/altenwald)

Enjoy!
