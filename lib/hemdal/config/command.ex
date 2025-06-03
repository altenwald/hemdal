defmodule Hemdal.Config.Command do
  @moduledoc """
  The command structure is defining the command to be executed inside of
  each alert. The data used is:

  - `name` the name of the script.
  - `type` the type of the script could be `line`, `shell` or `script`.
    The first one let us define a command in a single line,
    the last one let us define a script, a multi-line code which will be
    copied and executed in the host, and the last one let us run a command
    interacting with a process for providing information in runtime.
    The type `shell` is different to the others because it has no command
    to run and it should be `interactive`, indeed it configures interactive
    by default as `true`.
  - `interactive` specify if the command is handled in an interactive way
    (default: false).
  - `output` specify if the output should be stored (default: true).
  - `idle_timeout` specify the time between interactions that the interactive
    execution will be kept open in milliseconds (default: 60_000).
  - `decode` says if we should decode (JSON) the output or not (default: true).
  - `command` as the command line to be executed. It could be only one line
    or a multi-line script.
  """

  use Construct do
    field(:name, :string)
    field(:type, :string)
    field(:interactive, :boolean, default: false)
    field(:output, :boolean, default: true)
    field(:idle_timeout, :integer, default: :timer.minutes(1))
    field(:decode, :boolean, default: true)
    field(:command, :string, default: nil)
  end
end
