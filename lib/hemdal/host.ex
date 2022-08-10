defmodule Hemdal.Host do
  use GenServer, restart: :transient
  require Logger

  @default_temporal_dir "/tmp"
  @default_shell "/bin/bash"

  @timeout_exec 60_000

  @registry_name Hemdal.Host.Registry
  @sup_name Hemdal.Host.Supervisor

  defp via(name) do
    {:via, Registry, {@registry_name, name}}
  end

  def start(host) do
    DynamicSupervisor.start_child(@sup_name, {__MODULE__, [self(), host]})

    receive do
      :continue -> :ok
    after
      1_000 -> :error
    end
  end

  def start_link([parent, host]) do
    Logger.info("starting #{host.id} - #{host.name}")
    GenServer.start_link(__MODULE__, [parent, host], name: via(host.id))
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
    Hemdal.Config.get_all_hosts()
    |> Enum.each(&update_host/1)
  end

  def update_host(host) do
    if exists?(host.id) do
      GenStateMachine.cast(via(host.id), {:update, host})
      {:ok, get_pid(host.id)}
    else
      start(host)
    end
  end

  defstruct host: nil,
            workers: nil,
            queue: []

  @impl GenServer
  @doc false
  def init([parent, host]) do
    send(parent, :continue)
    {:ok, %__MODULE__{host: host, workers: host.max_workers}}
  end

  @impl GenServer
  @doc false
  def handle_call({:exec, cmd, args}, from, %__MODULE__{workers: w, queue: q} = state)
      when w == 0 or q != [] do
    w = if w > 0, do: w - 1, else: w
    Logger.debug("host => workers: #{w} ; queue_len: #{length(q) + 1}")
    {:noreply, %__MODULE__{state | queue: state.queue ++ [{from, cmd, args}], workers: w}}
  end

  def handle_call({:exec, cmd, args}, from, state) do
    spawn_monitor(fn -> run_in_background(cmd, args, from, state) end)
    workers = state.workers - 1
    Logger.debug("host => workers: #{workers} ; queue_len: #{length(state.queue)}")
    {:noreply, %__MODULE__{state | workers: workers}}
  end

  @impl GenServer
  @doc false
  def handle_cast({:update, host}, state) do
    diff_workers = host.max_workers - state.host.max_workers
    Logger.debug("reload host #{host.description} workers #{state.workers}+(#{diff_workers})")
    {:noreply, %__MODULE__{host: host, workers: state.workers + diff_workers}}
  end

  @impl GenServer
  @doc false
  def handle_info(
        {:DOWN, _ref, :process, _pid, _reason},
        %__MODULE__{queue: []} = state
      ) do
    workers = state.workers + 1
    Logger.debug("host => workers: #{workers} ; queue_len: 0")
    {:noreply, %__MODULE__{state | workers: workers}}
  end

  def handle_info(
        {:DOWN, _ref, :process, _pid, _reason},
        %__MODULE__{queue: [{from, cmd, args} | queue]} = state
      ) do
    state = %__MODULE__{state | queue: queue}
    spawn_monitor(fn -> run_in_background(cmd, args, from, state) end)
    Logger.debug("host => workers: #{state.workers} ; queue_len: #{length(queue)}")
    {:noreply, state}
  end

  defp run_in_background(cmd, args, from, %__MODULE__{host: host}) do
    mod = Module.concat([__MODULE__, host.type])

    result =
      mod.transaction(host, fn trooper ->
        with {:ok, errorlevel, output} <- exec_cmd(trooper, mod, cmd, args),
             {:ok, %{"status" => status} = data} <- decode(output) do
          Logger.debug("command exit(#{errorlevel}) output: #{inspect(data)}")

          cond do
            errorlevel == 2 or status == "FAIL" ->
              {:error, Map.put(data, "status", "FAIL")}

            errorlevel == 1 or status == "WARN" ->
              {:error, Map.put(data, "status", "WARN")}

            errorlevel == 0 or status == "OK" ->
              {:ok, Map.put(data, "status", "OK")}

            true ->
              {:error, Map.put(data, "status", "UNKNOWN")}
          end
        else
          other -> other
        end
      end)

    reply =
      case result do
        {:ok, %{"status" => "OK"} = data} ->
          {:ok, data}

        {:ok, %{} = result} ->
          {:error, %{"status" => "UNKNOWN", "message" => "#{inspect(result)}"}}

        {:error, error} when is_binary(error) ->
          {:error, %{"message" => error, "status" => "UNKNOWN"}}

        {:error, %{"status" => _} = error} ->
          {:error, error}

        {:error, error} ->
          {:error, %{"message" => "#{inspect(error)}", "status" => "UNKNOWN"}}

        other when not is_binary(other) ->
          Logger.error("error => #{inspect(other)}")
          {:error, %{"message" => "#{inspect(other)}", "status" => "FAIL"}}

        other ->
          Logger.error("error => #{other}")
          {:error, %{"message" => other, "status" => "FAIL"}}
      end

    GenServer.reply(from, reply)
  end

  defp decode(output) do
    case Jason.decode(output) do
      {:ok, [status, message]} ->
        {:ok, %{"status" => status, "message" => message}}

      {:ok, status} when is_binary(status) ->
        {:ok, %{"status" => status}}

      {:error, %Jason.DecodeError{data: error}} ->
        {:error, %{"message" => error, "status" => "UNKNOWN"}}

      other_resp ->
        other_resp
    end
  end

  defp random_string do
    :rand.uniform(0x100000000)
    |> Integer.to_string(36)
    |> String.downcase()
    |> String.pad_leading(7, "0")
  end

  defp exec_cmd(trooper, mod, %{command_type: "line", command: command}, _args) do
    mod.exec(trooper, command)
  end

  defp exec_cmd(trooper, mod, %{command_type: "script", command: script}, args) do
    tmp_file = Path.join([@default_temporal_dir, random_string()])

    try do
      sh =
        case String.split(script, ["\n"], trim: true) do
          "#!" <> shell -> shell
          _ -> @default_shell
        end

      mod.write_file(trooper, tmp_file, script)
      cmd = Enum.join([sh, tmp_file | args], " ")
      mod.exec(trooper, cmd)
    after
      mod.delete(trooper, tmp_file)
    end
  end

  @type opts() :: Keyword.t()
  @type handler() :: any
  @type command() :: String.t()
  @type errorlevel() :: integer()
  @type output() :: String.t()
  @type reason() :: any

  @callback transaction(opts(), (handler() -> any)) :: any

  @callback exec(handler(), command()) :: {:ok, errorlevel(), output()} | {:error, reason()}

  @callback write_file(handler(), tmp_file :: String.t(), content :: String.t()) ::
              :ok | {:error, reason()}

  @callback delete(handler(), tpm_file :: String.t()) :: :ok | {:error, reason()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Hemdal.Host
    end
  end
end
