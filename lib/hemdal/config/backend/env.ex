defmodule Hemdal.Config.Backend.Env do
  use Hemdal.Config

  defp get_config do
    Application.fetch_env!(:hemdal, Hemdal.Config)
  end

  @impl Hemdal.Config
  def get_all_hosts do
    get_config()
    |> Enum.map(& &1[:host])
    |> Enum.uniq()
    |> Enum.map(&Hemdal.Config.Host.make!/1)
  end

  @impl Hemdal.Config
  def get_all_alerts do
    get_config()
    |> Enum.map(&Hemdal.Config.Alert.make!/1)
  end
end
