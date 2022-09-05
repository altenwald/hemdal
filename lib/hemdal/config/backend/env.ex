defmodule Hemdal.Config.Backend.Env do
  @moduledoc """
  Configuration backend reader using the environment or Elixir configuration.
  See `Hemdal.Config.Backend` for further information.

  The backend is needing the configuration (see `Application` or `Config`)
  for specify the configuration as follows:

  ```elixir
  # config/config.exs
  import Config

  config :hemdal, Hemdal.Config, [
    [
      id: "36c16e85-7221-4021-8d6d-89f38a6d136c",
      name: "valid alert check",
      enabled: true,
      host: [
        id: "ec8fff22-41c2-4245-8a7b-5157d40c33a7",
        module: Hemdal.Host.Local,
        name: "localhost"
      ],
      command: [
        name: "get ok status",
        type: "line",
        command: "echo '[\"OK\", \"valid one!\"]'"
      ],
      check_in_sec: 60,
      recheck_in_sec: 1,
      broken_recheck_in_sec: 10,
      retries: 1
    ]
  ]
  ```

  See `Hemdal.Config.Alert` and `Hemdal.Config.Host` for further information.
  """
  use Hemdal.Config

  defp get_config do
    Application.fetch_env!(:hemdal, Hemdal.Config)
  end

  @doc """
  Retrieve the full list of the hosts which appear in the environment
  configuration.
  """
  @impl Hemdal.Config
  @spec get_all_hosts() :: [Hemdal.Config.Host.t()]
  def get_all_hosts do
    get_config()
    |> Enum.map(& &1[:host])
    |> Enum.uniq()
    |> Enum.map(&Hemdal.Config.Host.make!/1)
  end

  @doc """
  Retrieve the full list of the alerts which appear in the environment
  configuration.
  """
  @impl Hemdal.Config
  @spec get_all_alerts() :: [Hemdal.Config.Alert.t()]
  def get_all_alerts do
    get_config()
    |> Enum.map(&Hemdal.Config.Alert.make!/1)
  end
end
