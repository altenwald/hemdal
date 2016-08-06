defmodule Heimdall.Check do
    require Logger
    use GenServer

    alias Heimdall.Check.Host

    # 15 min
    @timeout 900

    @hostdict Heimdall.Check.HostDict

    defp check_host(host) do
        Agent.get_and_update(@hostdict, fn hosts ->
            case List.keyfind(hosts, host, 0) do
                {^host, pid} ->
                    {pid, hosts}
                nil ->
                    {:ok, pid} = Host.start_link(host)
                    {pid, hosts ++ [{host, pid}]}
            end
        end)
    end

    defp checks() do
        Application.get_env(:heimdall, :checks)
        |> Enum.each(fn({groupkey, values}) ->
            Logger.info("group #{groupkey}")
            Enum.each(values, fn({key, config}) ->
                Logger.debug("command: #{config[:command]}")
                Enum.map(config[:hosts], fn(host) ->
                    pid = check_host(host)
                    Logger.info("running check #{key} in #{host}")
                    Host.run(pid, groupkey, key, host, config)
                end)
            end)
        end)
    end

    defp timeout() do
        Application.get_env(:heimdall, :time_to_check, @timeout) * 1000
    end

    def start_link() do
        GenServer.start_link(__MODULE__, [], [name: __MODULE__])
    end

    def init([]) do
        {:ok, _} = Agent.start_link(fn -> [] end, name: @hostdict)
        {:ok, checks(), timeout()}
    end

    def handle_info(:timeout, _state) do
        {:noreply, checks(), timeout()}
    end
end
