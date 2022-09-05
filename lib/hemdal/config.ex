defmodule Hemdal.Config do
  @moduledoc """
  Hemdal needs to load a configuration to get the checks to be processed,
  how to trigger the alerts and how to connect to the systems to perform
  the checks.

  This module define all of the data needed for the configuration and the
  contract needed to be followed for the libraries which are going to act
  as backend systems.

  The backend is configured in the following way:

  ```elixir
  # config/config.exs
  config :hemdal, config_module: Hemdal.Config.Backend.Env
  ```

  The possible backends and supported officially are:

  - `Hemdal.Config.Backend.Env` which is configuring via `config.exs` in
    the Elixir configuration way.
  - `Hemdal.Config.Backend.Json` which is using JSON files.

  Check those modules to get further information about the implementation
  and usage.
  """
  alias Hemdal.Config.{Alert, Host}

  defp backend, do: Application.fetch_env!(:hemdal, :config_module)

  @doc """
  Get all of the alerts. It should provide a way to retrieve a list with
  the alerts in the format defined by `Hemdal.Config.Alert` or an empty
  list.
  """
  @callback get_all_alerts() :: [Alert.t()]

  @doc """
  Retrieve all of the alerts using the configured backend.
  """
  def get_all_alerts, do: backend().get_all_alerts()

  @doc """
  Retrieve an alert giving an `alert_id`.
  """
  @callback get_alert_by_id!(id :: String.t()) :: Alert.t() | nil

  @doc """
  Retrieves the alert giving an `alert_id` using the configured backend.
  """
  def get_alert_by_id!(id), do: backend().get_alert_by_id!(id)

  @doc """
  Retrieve all of the hosts. The implementation of this callback should
  provide a list of `Hemdal.Config.Host` or an empty list.
  """
  @callback get_all_hosts() :: [Host.t()]

  @doc """
  Retrieve all of the hosts using the configured backend.
  """
  def get_all_hosts, do: backend().get_all_hosts()

  @doc """
  Retrieve the host giving a `host_id`.
  """
  @callback get_host_by_id!(id :: String.t()) :: Host.t() | nil

  @doc """
  Retrieve the host giving a `host_id` using the configured backend.
  """
  def get_host_by_id!(id), do: backend().get_host_by_id!(id)

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Hemdal.Config

      @impl Hemdal.Config
      def get_host_by_id!(id) do
        get_all_hosts()
        |> Enum.find(&(&1.id == id))
      end

      @impl Hemdal.Config
      def get_alert_by_id!(id) do
        get_all_alerts()
        |> Enum.find(&(&1.id == id))
      end

      defoverridable get_host_by_id!: 1,
                     get_alert_by_id!: 1
    end
  end
end
