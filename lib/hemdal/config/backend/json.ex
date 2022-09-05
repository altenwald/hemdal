defmodule Hemdal.Config.Backend.Json do
  @moduledoc """
  Configuration backend reader using JSON. See `Hemdal.Config.Backend` for
  further information.

  The backend is needing the configuration (see `Application` or `Config`)
  to know where the JSON file is located. You can write in the configuration
  an entry like this:

  ```elixir
  # config/config.exs
  import Config

  config :hemdal, Hemdal.Config,
    hosts_file: "hosts.json",
    alerts_file: "alerts.json"
  ```

  The hosts file is intended to configure all of the necessary hosts to be
  accessible to run the checks and the alerts are the configuration for each
  check.

  An example of the hosts file is as follows:

  ```json
  [
    {
      "id": "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
      "name": "localhost",
      "type": "Local",
      "max_workers": 1
    }
  ]
  ```

  And an example for the alerts file is as follows:

  ```json
  [
    {
      "id": "52d13d6d-f217-4152-965d-cf5f488ceac4",
      "name": "valid alert check",
      "host_id": "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
      "command": {
        "name": "get ok status",
        "type": "line",
        "command": "echo '[\"OK\", \"valid one!\"]'"
      }
    }
  ]
  ```

  If you want to know more about what are the parameters you can use,
  see `Hemdal.Config.Alert` and `Hemdal.Config.Host` for further information.
  """
  use Hemdal.Config

  defp get_config(file) do
    Application.fetch_env!(:hemdal, Hemdal.Config)[file]
    |> File.read!()
    |> Jason.decode!()
  end

  @doc """
  Get all of the alerts. It's reading the alerts file specified in the
  configuration and the hosts file to create the full information for
  the alert.
  """
  @impl Hemdal.Config
  @spec get_all_alerts() :: [Hemdal.Config.Alert.t()]
  def get_all_alerts do
    hosts =
      get_config(:hosts_file)
      |> Enum.group_by(& &1["id"])
      |> Enum.map(fn {key, [value]} -> {key, value} end)
      |> Map.new()

    get_config(:alerts_file)
    |> Enum.map(fn alert ->
      host = process_credentials(hosts[alert["host_id"]])

      alert
      |> Map.delete("host_id")
      |> Map.put("host", host)
    end)
    |> Enum.map(&Hemdal.Config.Alert.make!/1)
  end

  @doc """
  Get all of the hosts. It's reading the hosts file specified in the
  configuration and returning it as a list of `Hemdal.Config.Host`
  elements.
  """
  @impl Hemdal.Config
  @spec get_all_hosts() :: [Hemdal.Config.Host.t()]
  def get_all_hosts do
    get_config(:hosts_file)
    |> Enum.map(&process_credentials/1)
    |> Enum.map(&Hemdal.Config.Host.make!/1)
  end

  defp process_credentials(%{"credential" => credential} = host) do
    credential =
      credential
      |> case do
        %{"cert_key" => "file:" <> file} = credential ->
          Map.put(credential, "cert_key", File.read!(file))

        credential ->
          credential
      end
      |> case do
        %{"cert_pub" => "file:" <> file} = credential ->
          Map.put(credential, "cert_pub", File.read!(file))

        credential ->
          credential
      end

    Map.put(host, "credential", credential)
  end

  defp process_credentials(host), do: host
end
