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

  alias Hemdal.Config.Schema

  @fields [
    {:name, :string, []},
    {:type, :string, []},
    {:interactive, :boolean, [default: false]},
    {:output, :boolean, [default: true]},
    {:idle_timeout, :integer, [default: :timer.minutes(1)]},
    {:decode, :boolean, [default: true]},
    {:command, :string, [default: nil]}
  ]

  @type t() :: %__MODULE__{
          name: String.t() | nil,
          type: String.t() | nil,
          interactive: boolean(),
          output: boolean(),
          idle_timeout: integer(),
          decode: boolean(),
          command: String.t() | nil
        }

  defstruct name: nil,
            type: nil,
            interactive: false,
            output: true,
            idle_timeout: :timer.minutes(1),
            decode: true,
            command: nil

  @spec make(map() | keyword(), keyword()) :: {:ok, t()} | {:error, map()}
  def make(params \\ %{}, opts \\ []), do: Schema.make(__MODULE__, @fields, params, opts)

  @spec make!(map() | keyword(), keyword()) :: t()
  def make!(params \\ %{}, opts \\ []), do: Schema.make!(__MODULE__, @fields, params, opts)
end
