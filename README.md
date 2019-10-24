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

## Documentation

Documentation is available through [hexdocs here](https://hexdocs.pm/hemdal).

## Why LGPL?!?

Despite of a lot of people think, LGPL it's not too restrictive. It's like many others around (MIT, BSD, Apache, ...) but makes an extra-effort to keep this code (and only this code, not yours) always free (free as freedom and not like a free beer).

Said that, if you want to include this code with your code (propietary or with other licences), you can! there is no problem! The only restriction is: **when you make modifications in THIS code, you should to share them** and all of the community will be grateful if you open a pull request to get feedback to the original project ;-).

## What's next?

Check the [documentation](https://hexdocs.pm/hemdal) first and, if you find something wrong, broken or you want to make a suggestion or ask something, you can open an issue via Github issues. Also you can provide PR (pull requests) with fixes if you catch some of them, or provide some features. Keep in mind our [Code of Conduct](CODE_OF_CONDUCT.md). You can also check [our documentation about how to contributing to get further information](CONTRIBUTING.md).

Don't forget to support us if you find this project interesting enough:

[![Paypal: Donation](https://img.shields.io/badge/paypal-donation-yellow)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=RC5F8STDA6AXE)
[![Patreon: Donation](https://img.shields.io/badge/patreon-donation-yellow)](https://www.patreon.com/altenwald)

Enjoy!
