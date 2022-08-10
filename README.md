# Hemdal Alerts/Alarms Panel

[![Build Status](https://img.shields.io/travis/altenwald/hemdal/master.svg)](https://travis-ci.org/altenwald/hemdal)
[![Codecov](https://img.shields.io/codecov/c/github/altenwald/hemdal.svg)](https://codecov.io/gh/altenwald/hemdal)
[![License: LGPL 2.1](https://img.shields.io/github/license/altenwald/hemdal.svg)](https://raw.githubusercontent.com/altenwald/hemdal/master/COPYING)
[![Paypal: Donation](https://img.shields.io/badge/paypal-donation-yellow)](https://www.paypal.com/donate/?hosted_button_id=XK6Z5XATN77L2)
[![Patreon: Donation](https://img.shields.io/badge/patreon-donation-yellow)](https://www.patreon.com/altenwald)

Alerts/Alarms library to get notified when an error or recovery happens.

Features:

- Extensible architecture, it let us add:
  - Hemdal.Host providing a way to run commands, at the moment [Trooper](https://github.com/army-cat/trooper) and Local.
  - Hemdal.Event is using [GenStage](https://hex.pm/packages/gen_stage), we can consume events.
  - Hemdal.Notifier is sending events outside, it's using at the moment Slack and Mattermost.
  - Hemdal.Config.Backend is letting us read the configuration from different places: Env and Json.
- Connecting proactively to the servers (no agents needed):
  - SSH user and password configuration.
  - SSH user and certificate (RSA, DSA and ECDSA).
  - SFTP to send scripts commands to run.
- Enable/Disable alerts.
- Reload configuration.

## Documentation

Documentation is available through [hexdocs here](https://hexdocs.pm/hemdal).

## Why LGPL?!?

Despite of a lot of people think, LGPL it's not too restrictive. It's like many others around (MIT, BSD, Apache, ...) but makes an extra-effort to keep this code (and only this code, not yours) always free (free as freedom and not like a free beer).

Said that, if you want to include this code with your code (propietary or with other licences), you can! there is no problem! The only restriction is: **when you make modifications in THIS code, you should to share them** and all of the community will be grateful if you open a pull request to get feedback to the original project ;-).

## What's next?

Check the [documentation](https://hexdocs.pm/hemdal) first and, if you find something wrong, broken or you want to make a suggestion or ask something, you can open an issue via Github issues. Also you can provide PR (pull requests) with fixes if you catch some of them, or provide some features. Keep in mind our [Code of Conduct](CODE_OF_CONDUCT.md). You can also check [our documentation about how to contributing to get further information](CONTRIBUTING.md).

Don't forget to support us if you find this project interesting enough:

[![paypal](https://www.paypalobjects.com/en_US/GB/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=XK6Z5XATN77L2)

Enjoy!
