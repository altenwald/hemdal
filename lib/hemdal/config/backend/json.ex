defmodule Hemdal.Config.Backend.Json do
  use Hemdal.Config

  defp get_config(file) do
    Application.fetch_env!(:hemdal, Hemdal.Config)[file]
    |> File.read!()
    |> Jason.decode!()
  end

  @impl Hemdal.Config
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

  @impl Hemdal.Config
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
