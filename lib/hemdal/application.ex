defmodule Hemdal.Application do
  @moduledoc false

  use Application
  require Logger

  @impl Application
  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Start the event manager
      Hemdal.Event,
      # Start the event log
      Hemdal.Event.Log,
      # Start the event notifications (to send to Slack and others)
      Hemdal.Event.Notification,
      # Start the registry and sup to content the checks (based on database UUID)
      {Registry, keys: :unique, name: Hemdal.Check.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Hemdal.Check.Supervisor},
      # Start the registry and sup for hosts
      {Registry, keys: :unique, name: Hemdal.Host.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Hemdal.Host.Supervisor}
    ]

    opts = [strategy: :one_for_one, name: Hemdal.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def start_phase(:preload_checks, :normal, _args), do: :ok

  if Mix.env() == :test do
    def start_phase(:load_checks, :normal, _args), do: :ok
  else
    def start_phase(:load_checks, :normal, _args) do
      Hemdal.Host.start_all()
      Hemdal.Check.start_all()
      :ok
    end
  end

  def start_phase(:postload_checks, :normal, _args), do: :ok
end
