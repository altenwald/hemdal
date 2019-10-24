defmodule Hemdal.Host.Conn do
  use GenServer, restart: :transient
  require Logger

  alias Hemdal.{Host, Cred, Command}

  @rsa_header "-----BEGIN RSA PRIVATE KEY-----"
  @dsa_header "-----BEGIN DSA PRIVATE KEY-----"
  @ecdsa_header "-----BEGIN EC PRIVATE KEY-----"

  @default_temporal_dir "/tmp"
  @default_shell "/bin/bash"

  @timeout_exec 60_000

  @registry_name Hemdal.Host.Conn.Registry
  @sup_name Hemdal.Host.Conn.Supervisor

  defp via(name) do
    {:via, Registry, {@registry_name, name}}
  end

  def start(host) do
    DynamicSupervisor.start_child @sup_name, {__MODULE__, [self(), host]}
    receive do
      :continue -> :ok
    after 1_000 -> :error
    end
  end

  def start_link([parent, host]) do
    Logger.info "starting #{host.id} - #{host.name}"
    GenServer.start_link __MODULE__, [parent, host], name: via(host.id)
  end

  def exists?(name) do
    case Registry.lookup(@registry_name, name) do
      [{_pid, nil}] -> true
      [] -> false
    end
  end

  def exec(id, cmd, args) do
    GenServer.call(via(id), {:exec, cmd, args}, @timeout_exec)
  end

  def get_pid(name) do
    case Registry.lookup(@registry_name, name) do
      [{pid, nil}] -> pid
      [] -> nil
    end
  end

  def reload_all do
    Host.get_all()
    |> Enum.each(&update_host/1)
  end

  def update_host(host) do
    if exists?(host.id) do
      GenStateMachine.cast via(host.id), {:update, host}
      {:ok, get_pid(host.id)}
    else
      start(host)
    end
  end

  defmodule State do
    defstruct host: nil,
              workers: nil,
              queue: []
  end

  @impl GenServer
  def init([parent, host]) do
    send(parent, :continue)
    {:ok, %State{host: host, workers: host.max_workers}}
  end

  @impl GenServer
  def handle_call({:exec, cmd, args}, from,
                  %State{workers: w, queue: q} = state)
                  when w == 0 or q != [] do
      w = if w > 0, do: w - 1, else: w
      Logger.debug "conn => workers: #{w} ; queue_len: #{length(q)+1}"
      {:noreply, %State{state | queue: state.queue ++ [{from, cmd, args}],
                                workers: w}}
  end
  def handle_call({:exec, cmd, args}, from, state) do
    spawn_monitor(fn -> run_in_background(cmd, args, from, state) end)
    workers = state.workers - 1
    Logger.debug "conn => workers: #{workers} ; queue_len: #{length(state.queue)}"
    {:noreply, %State{state | workers: workers}}
  end

  @impl GenServer
  def handle_cast({:update, host}, state) do
    diff_workers = host.max_workers - state.host.max_workers
    Logger.debug "reload host #{host.description} workers #{state.workers}+(#{diff_workers})"
    {:noreply, %State{host: host, workers: state.workers + diff_workers}}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, _reason},
                  %State{queue: []} = state) do
    workers = state.workers + 1
    Logger.debug "conn => workers: #{workers} ; queue_len: 0"
    {:noreply, %State{state | workers: workers}}
  end
  def handle_info({:DOWN, _ref, :process, _pid, _reason},
                  %State{queue: [{from, cmd, args}|queue]} = state) do
    state = %State{state | queue: queue}
    spawn_monitor(fn -> run_in_background(cmd, args, from, state) end)
    Logger.debug "conn => workers: #{state.workers} ; queue_len: #{length(queue)}"
    {:noreply, state}
  end

  defp run_in_background(cmd, args, from, %State{host: host}) do
    opts = [host: String.to_charlist(host.name),
            port: host.port,
            user: String.to_charlist(host.cred.username)] ++ auth_cfg(host.cred)
    result = :trooper_ssh.transaction(opts, fn(trooper) ->
      with {:ok, errorlevel, output} <- exec_cmd(trooper, cmd, args),
           {:ok, %{"status" => status} = data} <- decode(output) do
        Logger.debug("command exit(#{errorlevel}) output: #{inspect data}")
        cond do
          errorlevel == 0 or status == "OK" ->
            {:ok, Map.put(data, "status", "OK")}
          errorlevel == 1 or status == "WARN" ->
            {:error, Map.put(data, "status", "WARN")}
          errorlevel == 2 or status == "FAIL" ->
            {:error, Map.put(data, "status", "FAIL")}
          true ->
            {:error, Map.put(data, "status", "UNKNOWN")}
        end
      else
        other -> other
      end
    end)
    reply = case result do
      {:ok, %{"status" => "OK"} = data} -> {:ok, data}
      {:ok, %{} = result} ->
        {:error, %{"status" => "UNKNOWN", "message" => "#{inspect result}"}}
      {:error, error} when is_binary(error) ->
        {:error, %{"message" => error, "status" => "UNKNOWN"}}
      {:error, %{"status" => _} = error} -> {:error, error}
      {:error, error} ->
        {:error, %{"message" => "#{inspect error}", "status" => "UNKNOWN"}}
      other when not is_binary(other) ->
        Logger.error("error => #{inspect other}")
        {:error, %{"message" => "#{inspect other}",
                   "status" => "FAIL"}}
      other ->
        Logger.error("error => #{other}")
        {:error, %{"message" => other,
                   "status" => "FAIL"}}
    end
    GenServer.reply(from, reply)
  end

  defp decode(output) do
    case Jason.decode(output) do
      {:ok, [status, message]} ->
        {:ok, %{"status" => status, "message" => message}}
      {:error, %Jason.DecodeError{data: error}} ->
        {:error, %{"message" => error, "status" => "UNKNOWN"}}
      other_resp -> other_resp
    end
  end

  defp random_string do
    Integer.to_string(:rand.uniform(0x100000000), 36) |> String.downcase
  end

  defp exec_cmd(trooper, %Command{command_type: "line",
                                  command: command}, _args) do
    :trooper_ssh.exec(trooper, command)
  end
  defp exec_cmd(trooper, %Command{command_type: "script",
                                  command: script}, args) do
    tmp_file = Path.join([@default_temporal_dir, random_string()])
    try do
      sh = case String.split(script, ["\n"], trim: true) do
        "#!" <> shell -> shell
        _ -> @default_shell
      end
      :trooper_scp.write_file(trooper, tmp_file, script)
      cmd = Enum.join([sh, tmp_file|args], " ")
      :trooper_ssh.exec(trooper, cmd)
    after
      :trooper_scp.delete(trooper, tmp_file)
    end
  end

  defp auth_cfg(%Cred{type: "password", password: password}) do
    [password: String.to_charlist(password)]
  end
  defp auth_cfg(%Cred{type: "rsa", cert_key: rsa} = cred) do
    if not String.starts_with?(rsa, @rsa_header) do
      throw {:error, "Host with an invalid certificate"}
    end
    case cred.password do
      nil -> [id_rsa: rsa]
      password -> [id_rsa: rsa, rsa_pass_pharse: password]
    end
  end
  defp auth_cfg(%Cred{type: "dsa", cert_key: dsa} = cred) do
    if not String.starts_with?(dsa, @dsa_header) do
      throw {:error, "Host with an invalid certificate"}
    end
    case cred.password do
      nil -> [id_dsa: dsa]
      password -> [id_dsa: dsa, dsa_pass_pharse: password]
    end
  end
  defp auth_cfg(%Cred{type: "ecdsa", cert_key: ecdsa} = cred) do
    if not String.starts_with?(ecdsa, @ecdsa_header) do
      throw {:error, "Host with an invalid certificate"}
    end
    case cred.password do
      nil -> [id_ecdsa: ecdsa]
      password -> [id_ecdsa: ecdsa, dsa_pass_pharse: password]
    end
  end
end
