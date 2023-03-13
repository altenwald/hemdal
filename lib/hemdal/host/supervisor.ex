defmodule Hemdal.Host.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc false
  @impl Supervisor
  def init([]) do
    children = [
      {Registry, keys: :unique, name: Hemdal.Host.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Hemdal.Host.Supervisor}
    ]

    options = [strategy: :one_for_one]
    Supervisor.init(children, options)
  end
end
