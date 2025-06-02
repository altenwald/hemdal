defmodule Hemdal.Config.Alert do
  @moduledoc """
  Alert entity used for the alert configuration. It is including the following
  configuration params:

  - `id` the ID for the alert. Used for launching the process,
    see `Hemdal.Check`.
  - `enabled` let us know if the alert is enabled (ok, warn, or error) or
    disabled (in disabled status).
  - `name` the name provided to the alert.
  - `check_in_sec` the interval time (in seconds) to run the check. In `ok` or
    `normal` state.
  - `recheck_in_sec` the interval time (in seconds) where the command is
    failing and it should be checked a number of `retries` in this interval of
    time previously to move to `broken` state.
  - `broken_recheck_in_sec` the interval time (in seconds) where the command is
    running during the `broken` state.
  - `retries` is the number of retries we are running in `failing` state
    previously to determine it's broken.
  - `command_args` is a list of arguments to be in use with the command.
  - `host` is the `Hemdal.Config.Host` data.
  - `command` is a nested structure including the command to be executed,
    the name of the command, and the command type. See `Hemdal.Config.Command`.
  - `notifiers` is a list of `Hemdal.Config.Notifier`.
  """
  alias Hemdal.Config.{Command, Host, Notifier}

  use Construct do
    field(:id, :string)
    field(:enabled, :boolean, default: true)
    field(:name, :string)
    field(:check_in_sec, :integer, default: 60)
    field(:recheck_in_sec, :integer, default: 5)
    field(:broken_recheck_in_sec, :integer, default: 30)
    field(:retries, :integer, default: 3)
    field(:command_args, {:array, :string}, default: [])

    field(:host, Host)
    field(:command, Command)
    field(:notifiers, {:array, Notifier}, default: [])
  end
end
