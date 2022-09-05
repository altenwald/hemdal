# Getting started

Hemdal is a library designed to run commands and retrieve a result. It let us implement the different aspects of the system as we want and it's extensible enough to provide us ways of implementing extensions without modify the core code base.

Hemdal isn't a stand-alone system, if you need that kind of service, check [Hemdal UI](https://github.com/altenwald/hemdal_ui) which implements Hemdal User Interface with [Phoenix Framework](https://phoenixframework.org) and [Trooper](https://github.com/army-cat/trooper) for providing more features and a stand-alone way to run Hemdal.

## Understanding the layers

You need to understand the elements of Hemdal to know how to use it and extend it. The layers are:

- `Hemdal.Host` is the way Hemdal connect with the hosts to run commands. It's an implementation of a pool of hosts defined by the maximum number of tasks which could be running at the same time on the same host.
- `Hemdal.Check` is the state of each alarm/alert of the system. It's a state machine which is running in a defined interval of time a command against a host. Depending on the result it's generating information and changing its states.
- `Hemdal.Event` is the event generator, each time the state machine (`Hemdal.Check`) generates an event, it goes to this module and it's send to all of its consumers. It's based on `GenStage` and you can create as many consumers as you need.
- `Hemdal.Notifier` is a specific consumer for `Hemdal.Event` which have the mission to report the events to specific endpoints. You can implement new modules to provide new ways of notification.

These are the basic ways we can provide for extend the system.

## Hosts

At the moment, to connect to different hosts, we provide only one way, but because SSH is a bit more complicated, we created a new repository to show you how to extend Hemdal in a non-intrusive way to implement your own stuff:

- `Hemdal.Host.Local` is running commands using `System.shell/2`, it's not too fancy but it's useful.
- [`Hemdal.Host.Trooper`](https://github.com/altenwald/hemdal_trooper) is a way to implement SSH to connect to remote hosts.

See `Hemdal.Config.Host` to know how to configure and use them.

## Events

While there are different examples which you can see in the source code, it's easier to think about the events as a simple `GenStage` consumer. You can write your own, put under your own supervisor and consume from `Hemdal.Event`. You will receive always the `%Hemdal.Event{}` structure.

We have the implementation of the following event consumers:

- `Hemdal.Event.Log` which is triggering a log for each event received.
- `Hemdal.Event.Notification` which is converting the event into a notification for notifier.
- `Hemdal.Event.Mock` which is in use for test purposes.

## Notifiers

The notifiers are defined in the alert configuration (see `Hemdal.Config.Alert`). You can specify a list of notifiers to be in use every time a new event is triggering a notification.

We have defined the following notifiers:

- `Hemdal.Notifier.Slack` which is triggering a message for Slack system.
- `Hemdal.Notifier.Mattermost` which is triggering a message for Mattermost system.
- `Hemdal.Notifier.Mock` which is for testing purposes.
