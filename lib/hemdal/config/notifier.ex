defmodule Hemdal.Config.Notifier do
  @moduledoc """
  Notifier is in charge of define the amount of notifiers it should be
  in use for a notification, and the data to perform the notification.

  The available fields are the following ones:

  - `token` is the information needed to send a message for some
    platforms like Slack or Mattermost. But it could means even a
    password for an email backend.
  - `type` the name used to be concatenated to `Hemdal.Notifier` and
    find for the module.
  - `username` is the name of the user to show the notification. But
    it could means different things depending on the backend. For an
    email backend it could be the user/email to send the message.
  - `log_level` used to send the notifications. If we specify an
    `error` log level it will notify only when a change from/to error
    is happening. See `Hemdal.Event.Notification` for further
    information.
  - `metadata` the extra data sent to the notifier.
  """

  use Construct do
    field(:token, :string)
    field(:type, :string, default: "Slack")
    field(:username, :string)
    field(:log_level, :string, default: "warn")
    field(:metadata, :map, default: %{})
  end
end
