defmodule Hemdal do
  @moduledoc """
  Hemdal is a system for Alert/Alarm very customizable. It's based on
  [Nagios](https://www.nagios.com) where you have different scripts to check
  the status of different elements of your system providing back information
  about these checks.

  The Hemdal Core is agnostic to the way we can be
  connected to the external server to perform checks and even, we can
  implement our own agents in case the access or communication to the servers
  is difficult or requires customization.

  ## Motivation

  The problem with other systems like Nagios, Icinga or Sensu is they are
  based on the client/server infrastructure and requires to install an agent
  inside of each remote node. Hemdal is agnostic about the way of access to
  the host but it's more inclined to provide the mechanics needed to connect
  actively without agents. However, it's agnostic, it's meaning that we could
  implement an agent and access to the server using that agent.

  ## Hosts

  The way to run the checks depends on the host. By default, `hemdal_core` is
  only implementing `Local` which is running locally the commands using the
  same user as the hemdal core. The available and official hosts are the
  following ones:

  - `Local`, included with core.
  - [`Trooper`](https://github.com/altenwald/hemdal_trooper) uses
    [Trooper](https://github.com/army-cat/trooper) to connect via SSH to the
    remote servers.

  See `Hemdal.Config` for further information.

  ## Config

  The configuration is also abstracted using `Hemdal.Config`. We can use only
  one provider and this should be configured as follows:

  ```elixir
  # config/config.exs
  config :hemdal, :config_module, Hemdal.Config.Backend.Env

  config :hemdal, Hemdal.Config, [
    # here the checks configuration
  ]
  ```

  We have available the following official backends for the configuration:

  - `Hemdal.Config.Backend.Env`, as shown above, it's putting the whole
    configuration inside of the configuration file for Elixir.
  - `Hemdal.Config.Backend.Json`, it's specifying the JSON files to be
    loaded and they are loaded each time we are requesting data for the
    alerts.

  See `Hemdal.Config` for further information.

  ## Event

  When something is happening with the checks an event is generated. There
  are different ways to configure the way we receive the events and it's
  linked to the checks, see `Hemdal.Check` for further information.

  The events could be implemented via `GenStage`. See `Hemdal.Event` for
  futher information.

  ## Notification

  One of the event consumers is in charge of triggering notifications. These
  have a specific format. We have implementation at the moment for the
  following backends for the notifications:

  - `Hemdal.Notifier.Slack` is sending the event to a Slack webhook.
  - `Hemdal.Notifier.Mattermost` is sending the even to a Mattermost webhook.

  See `Hemdal.Notifier` for futher information.
  """

  @doc """
  Reload all of the alerts and hosts. See `Hemdal.Check.reload_all/0` and
  `Hemdal.Host.reload_all/0` for further information.
  """
  @spec reload_all() :: :ok
  def reload_all do
    Hemdal.Host.reload_all()
    Hemdal.Check.reload_all()
    :ok
  end

  @doc """
  Retrieve all the alerts. See `Hemdal.Check.get_all/0` for further
  information.
  """
  @spec get_all_alerts() :: [Hemdal.Check.returned_status()]
  defdelegate get_all_alerts, to: Hemdal.Check, as: :get_all

  @doc """
  Start the alert based on the alert ID.
  """
  @spec start_alert!(id :: String.t()) :: {:ok, pid()}
  def start_alert!(id) do
    Hemdal.Config.get_alert_by_id!(id)
    |> Hemdal.Check.start()
  end
end
