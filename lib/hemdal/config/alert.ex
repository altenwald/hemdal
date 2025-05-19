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
    the name of the command, and the command type. See
    `Hemdal.Config.Alert.Command`.
  - `notifiers` is a list of `Hemdal.Config.Notifier`.
  """
  alias Hemdal.Config.{Host, Notifier}

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

    field :command do
      @moduledoc """
      The command structure is defining the command to be executed inside of
      each alert. The data used is:

      - `name` the name of the script.
      - `type` the type of the script could be `line`, `script` or
        `interactive`. The first one let us define a command in a single line,
        the last one let us define a script, a multi-line code which will be
        copied and executed in the host, and the last one let us run a command
        interacting with a process for providing information in runtime.
      - `command` as the command line to be executed. It could be only one line
        or a multi-line script.
      """
      field(:name, :string)
      field(:type, :string)
      field(:command, :string)
    end

    field(:notifiers, {:array, Notifier}, default: [])
  end
end
