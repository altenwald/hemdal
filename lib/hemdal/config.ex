defmodule Hemdal.Config do
  @moduledoc """
  Hemdal needs to load a configuration to get the checks to be processed,
  how to trigger the alerts and how to connect to the systems to perform
  the checks.

  This module define all of the data needed for the configuration and the
  contract needed to be followed for the libraries which are going to act
  as backend systems.
  """
  alias Hemdal.Config.{Alert, Host}

  defp backend, do: Application.fetch_env!(:hemdal, :config_module)

  @callback get_all_alerts() :: [Alert.t()]

  def get_all_alerts, do: backend().get_all_alerts()

  @callback get_alert_by_id!(id :: String.t()) :: Alert.t() | nil

  def get_alert_by_id!(id), do: backend().get_alert_by_id!(id)

  @callback get_all_hosts() :: [Host.t()]

  def get_all_hosts, do: backend().get_all_hosts()

  @callback get_host_by_id!(id :: String.t()) :: Host.t() | nil

  def get_host_by_id!(id), do: backend().get_host_by_id!(id)

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
