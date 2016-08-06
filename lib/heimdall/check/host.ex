defmodule Heimdall.Check.Host do
    require Logger
    use GenFSM

    @options [:exit_status, :in]
    @regex ~r/^([0-9A-Za-z_:.-]+) (OK|CRITICAL|WARNING) (.+)/u

    defmodule StateData do
        defstruct queue: [],
                  host: "",
                  output: "",
                  groupkey: "",
                  key: "",
                  description: "",
                  command: "",
                  port: nil
    end

    def start_link(host) do
        :gen_fsm.start_link(__MODULE__, [host], [])
    end

    def run(pid, groupkey, key, host, config) do
        :gen_fsm.send_event(pid, {:enqueue, {groupkey, key, host, config}})
    end

    def run_now(host, config) do
        # TODO: implement different ways to run configurations
        command = "ssh #{host} #{config[:command]}"
        case config[:wait_for_connect] do
            nil -> :ok
            time ->
                Logger.debug("waiting #{time}000ms for #{command} in #{host}")
                Process.sleep(time * 1000)
        end
        port = Port.open({:spawn, command}, @options)
        Process.send_after(self(), {:timeout, port}, 15000)
        port
    end

    def init([host]) do
        {:ok, :idle, %StateData{host: host}}
    end

    def idle(:check, %StateData{queue: []} = statedata) do
        {:next_state, :idle, statedata}
    end

    def idle(:check, %StateData{queue: [to_run|rest]} = statedata) do
        {groupkey, key, host, config} = to_run
        port = run_now(host, config)
        {:next_state, :running, %StateData{statedata | queue: rest,
                                                       groupkey: groupkey,
                                                       key: key,
                                                       port: port,
                                                       command: config[:command],
                                                       description: config[:name],
                                                       output: ""}}
    end

    def idle({:enqueue, runinfo}, %StateData{queue: []} = statedata) do
        {groupkey, key, host, config} = runinfo
        port = run_now(host, config)
        {:next_state, :running, %StateData{statedata | groupkey: groupkey,
                                                       key: key,
                                                       port: port,
                                                       command: config[:command],
                                                       description: config[:name],
                                                       output: ""}}
    end

    def idle({:enqueue, runinfo}, %StateData{queue: [to_run|rest]} = statedata) do
        {groupkey, key, host, config} = to_run
        port = run_now(host, config)
        queue = rest ++ [runinfo]
        {:next_state, :running, %StateData{statedata | queue: queue,
                                                       groupkey: groupkey,
                                                       key: key,
                                                       port: port,
                                                       command: config[:command],
                                                       description: config[:name],
                                                       output: ""}}
    end

    def running(:check, statedata) do
        {:next_state, :running, statedata}
    end

    def running({:enqueue, runinfo}, %StateData{queue: queue} = statedata) do
        {:next_state, :running, %StateData{statedata | queue: queue ++ [runinfo]}}
    end

    def handle_info({port, {:data, string}}, :running, %StateData{port: port}=statedata) do
        %StateData{output: prev_output, groupkey: gk, key: k, host: host} = statedata
        Logger.debug("[#{host}][#{gk}][#{k}] received: #{IO.inspect(string)}")
        case Regex.run(regex(), List.to_string(string)) do
            [_, name, status, comment] ->
                new_output = [name, status, comment] |> Enum.join(" ")
                output = prev_output <> new_output
                {:next_state, :running, %StateData{statedata | output: output}}
            nil ->
                {:next_state, :running, statedata}
        end
    end

    def handle_info({port, {:exit_status, es}}, :running, statedata) do
        %StateData{queue: queue, output: o, groupkey: gk, command: command,
                   key: k, host: host, description: desc} = statedata
        if es == 255 do
            Logger.error("[#{host}] command #{gk} failed -> #{command}")
            notify(host, Atom.to_string(gk), Atom.to_string(k), "FAIL", command)
        else
            Logger.info("[#{host}][#{gk}][#{k}] notify #{es} -> #{IO.inspect(o)}")
            Task.async(fn ->
                save_info(gk, k, host, desc, o, es)
            end)
        end
        if queue != [] do
            :gen_fsm.send_event(self(), :check)
        end
        {:next_state, :idle, statedata}
    end

    # FIXME: sometimes the exit_status message doesn't arrive so, this workaround
    #        let us to close the request to the server and continue with the rest
    #        of commands.
    def handle_info({:timeout, port}, :running, %StateData{port: port}=statedata) do
        %StateData{output: output} = statedata
        es = case Regex.run(regex(), output) do
            [_, _name, "OK", _comment] -> 0
            [_, _name, "WARNING", _comment] -> 1
            [_, _name, "CRITICAL", _comment] -> 2
            _ -> 127
        end
        Port.close(port)
        handle_info({port, {:exit_status, es}}, :running, statedata)
    end

    def handle_info({:timeout, _port}, statename, statedata) do
        {:next_state, statename, statedata}
    end

    def handle_info({_ref, :ok}, statename, statedata) do
        {:next_state, statename, statedata}
    end

    def handle_info({:DOWN, _ref, :process, _pid, reason}, statename, statedata) do
        %StateData{output: o, groupkey: gk, key: k, host: host} = statedata
        Logger.warn("[#{host}] command #{gk} failed #{k} -> #{reason}")
        {:next_state, statename, statedata}
    end

    defp regex() do
        Application.get_env(:heimdall, :regex, @regex)
    end

    defp save_info(groupkey, name, hostname, description, output, exit_status) do
        groupkey = Atom.to_string(groupkey)
        name = Atom.to_string(name)
        changeset = Heimdall.Notification.changeset(
            %Heimdall.Notification{},
            %{"hostname" => hostname,
              "groupkey" => groupkey,
              "name" =>  name,
              "description" => description,
              "status_text" => output,
              "status" => exit_status})
        case Heimdall.Notification.find(hostname, groupkey, name) do
            nil -> notify(hostname, groupkey, name, "NEW", output)
            %Heimdall.Notification{status: st} when st != exit_status ->
                case exit_status do
                    0 -> notify(hostname, groupkey, name, "OK", output)
                    1 -> notify(hostname, groupkey, name, "WARNING", output)
                    256 -> notify(hostname, groupkey, name, "UNKNOWN", output)
                    _ -> notify(hostname, groupkey, name, "CRITICAL", output)
                end
            %Heimdall.Notification{} ->
                :ok
        end
        Heimdall.Repo.insert(changeset)
        Heimdall.Notification.remove_old()
        :ok
    end

    def notify(hostname, groupkey, name, status, output) do
        Logger.info("[#{hostname}][#{groupkey}][#{name}] sending notification for #{status}")
        notification = Application.get_env(:heimdall, :notification)
        # TODO develop more notifications services
        case notification[:slack] do
            nil ->
                Logger.error("slack URL is not defined!")
            url ->
                message = "In *#{hostname}* client *#{groupkey}* " <>
                          "service *#{name}* status: " <>
                          "*<http://heimdall.altenwald.com|#{status}>* " <>
                          "\n> #{output}"
                HTTPoison.post!(url, Poison.encode!(%{"text": message}))
        end
    end
end
