defmodule Hemdal.Config.Host do
  @moduledoc """
  The host information.
  """

  alias Hemdal.Config.{MaxWorkers, Module, Options, Schema}

  @fields [
    {:id, :string, []},
    {:name, :string, []},
    {:module, Module, [default: Hemdal.Host.Local]},
    {:options, Options, [default: []]},
    {:max_workers, MaxWorkers, [default: 5]}
  ]

  @type t() :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          module: module(),
          options: Options.t(),
          max_workers: MaxWorkers.t()
        }

  defstruct id: nil,
            name: nil,
            module: Hemdal.Host.Local,
            options: [],
            max_workers: 5

  @spec make(map() | keyword(), keyword()) :: {:ok, t()} | {:error, map()}
  def make(params \\ %{}, opts \\ []), do: Schema.make(__MODULE__, @fields, params, opts)

  @spec make!(map() | keyword(), keyword()) :: t()
  def make!(params \\ %{}, opts \\ []), do: Schema.make!(__MODULE__, @fields, params, opts)
end
