defmodule Hemdal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl Application
  def start(_type, _args) do
    if Mix.env() == :prod do
      {:ok, _} = EctoBootMigration.migrate(:hemdal)
    end
    # List all child processes to be supervised
    children = [
      # Start the Ecto repository
      Hemdal.Repo,
      # Start the endpoint when the application starts
      HemdalWeb.Endpoint,
      # Start the event manager
      Hemdal.EventManager,
      # Start the event loggger
      Hemdal.EventLogger,
      # Start the event channel
      Hemdal.EventChannel,
      # Start the event notifications (to send to Slack and others)
      Hemdal.EventNotif,
      # Start the registry and sup to content the checks (based on database UUID)
      {Registry, keys: :unique, name: Hemdal.Check.Registry},
      {DynamicSupervisor, strategy: :one_for_one,
                          name: Hemdal.Check.Supervisor},
      # Start the registry and sup for hosts
      {Registry, keys: :unique, name: Hemdal.Host.Conn.Registry},
      {DynamicSupervisor, strategy: :one_for_one,
                          name: Hemdal.Host.Conn.Supervisor},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hemdal.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def start_phase(:load_checks, :normal, [:ignore]), do: :ok
  def start_phase(:load_checks, :normal, []) do
    Hemdal.Host.get_all()
    |> Enum.each(fn host ->
                  Logger.info "starting host #{host.description}"
                  Hemdal.Host.Conn.start host
                 end)
    Hemdal.Alert.get_all()
    |> Enum.each(fn check ->
                  Logger.info "starting check #{check.name}"
                  Hemdal.Check.start check
                 end)
    :ok
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    HemdalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
