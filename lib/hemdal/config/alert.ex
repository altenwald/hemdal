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
  alias Hemdal.Config.{Command, Host, Notifier, Schema}

  @fields [
    {:id, :string, []},
    {:enabled, :boolean, [default: true]},
    {:name, :string, []},
    {:check_in_sec, :integer, [default: 60]},
    {:recheck_in_sec, :integer, [default: 5]},
    {:broken_recheck_in_sec, :integer, [default: 30]},
    {:retries, :integer, [default: 3]},
    {:command_args, {:array, :string}, [default: []]},
    {:host, Host, []},
    {:command, Command, []},
    {:notifiers, {:array, Notifier}, [default: []]}
  ]

  @type t() :: %__MODULE__{
          id: String.t() | nil,
          enabled: boolean(),
          name: String.t() | nil,
          check_in_sec: integer(),
          recheck_in_sec: integer(),
          broken_recheck_in_sec: integer(),
          retries: integer(),
          command_args: [String.t()],
          host: Host.t() | nil,
          command: Command.t() | nil,
          notifiers: [Notifier.t()]
        }

  defstruct id: nil,
            enabled: true,
            name: nil,
            check_in_sec: 60,
            recheck_in_sec: 5,
            broken_recheck_in_sec: 30,
            retries: 3,
            command_args: [],
            host: nil,
            command: nil,
            notifiers: []

  @spec make(map() | keyword(), keyword()) :: {:ok, t()} | {:error, map()}
  def make(params \\ %{}, opts \\ []), do: Schema.make(__MODULE__, @fields, params, opts)

  @spec make!(map() | keyword(), keyword()) :: t()
  def make!(params \\ %{}, opts \\ []), do: Schema.make!(__MODULE__, @fields, params, opts)
end
