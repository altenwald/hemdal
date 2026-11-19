defmodule Hemdal.Config.Notifier do
  @moduledoc """
  Notifier is in charge of define the amount of notifiers it should be
  in use for a notification, and the data to perform the notification.

  The available fields are the following ones:

  - `token` is the information needed to send a message for some
    platforms like Slack or Mattermost. But it could means even a
    password for an email backend.
  - `module` specifies the notifier module to use, e.g. `Hemdal.Notifier.Slack`
    or `Hemdal.Notifier.Mattermost` (default: `Hemdal.Notifier.Slack`).
  - `username` is the name of the user to show the notification. But
    it could means different things depending on the backend. For an
    email backend it could be the user/email to send the message.
  - `log_level` used to send the notifications. If we specify an
    `error` log level it will notify only when a change from/to error
    is happening. See `Hemdal.Event.Notification` for further
    information.
  - `metadata` the extra data sent to the notifier.
  """

  alias Hemdal.Config.{Module, Schema}

  @fields [
    {:token, :string, []},
    {:module, Module, [default: Hemdal.Notifier.Slack]},
    {:username, :string, []},
    {:log_level, :string, [default: "warn"]},
    {:metadata, :map, [default: %{}]}
  ]

  @type t() :: %__MODULE__{
          token: String.t() | nil,
          module: module(),
          username: String.t() | nil,
          log_level: String.t(),
          metadata: map()
        }

  defstruct token: nil,
            module: Hemdal.Notifier.Slack,
            username: nil,
            log_level: "warn",
            metadata: %{}

  @spec make(map() | keyword(), keyword()) :: {:ok, t()} | {:error, map()}
  def make(params \\ %{}, opts \\ []), do: Schema.make(__MODULE__, @fields, params, opts)

  @spec make!(map() | keyword(), keyword()) :: t()
  def make!(params \\ %{}, opts \\ []), do: Schema.make!(__MODULE__, @fields, params, opts)
end
