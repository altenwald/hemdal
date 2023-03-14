defmodule Hemdal.Host do
  @moduledoc """
  Host is spawning processes to run tasks for the corresponding host. It's
  a way of limiting the amount of commands triggered against a host and
  ensure the rest of the commands stay in the queue.

  It's also the base for the implementation of the way of running commands.
  At the moment the available way to run commands are:

  - `Hemdal.Host.Local` intended to run local commands.
  - `Hemdal.Host.Trooper` intended to run SSH commands. It's not included
    in the main repository, you can find more information
    [here](https://github.com/altenwald/hemdal_trooper).

  If you want to know more about what could be included in a command or
  to be run in a host you can review the following modules:

  - `Hemdal.Config.Alert.Command` where you can check what's included
    inside of the command.
  - `Hemdal.Config.Host` where you can find information about the host.

  ## Implement a new Host

  If you need to implement a new way to run external commands, you can
  create a new `Hemdal.Host.XXX` module which will be using the module
  `Hemdal.Host` inside. For example, if you need to implement a telnet
  way to access to the remote hosts, you can implement a module as follows:

  ```elixir
  defmodule Hemdal.Host.Telnet do
    use Hemdal.Host

    @impl Hemdal.Host
    def exec(host, command) do
      # do your stuff
      {:ok, errorlevel, output}
    end

    @impl Hemdal.Host
    def write_file(host, filename, content) do
      raise "Impossible to transfer files"
    end

    @impl Hemdal.Host
    def delete(host, filename) do
      raise "Impossible to remove files"
    end
  end
  ```

  While telnet isn't prepared to transfer files, it's raising an error
  which is telling the system that's impossible to use the script way
  for running commands.
  """
  use GenServer, restart: :transient
  require Logger
  alias Hemdal.Config.Alert.Command
  alias :queue, as: Queue

  @default_temporal_dir "/tmp"
  @default_shell "/bin/bash"

  @timeout_exec 60_000

  @registry_name Hemdal.Host.Registry
  @sup_name Hemdal.Host.Supervisor

  defp via(name) do
    {:via, Registry, {@registry_name, name}}
  end

  @doc """
  Start a new host under the `Hemdal.Host.Supervisor` module.
  """
  @spec start(Hemdal.Config.Host.t()) :: :ok
  def start(host) do
    {:ok, _} = DynamicSupervisor.start_child(@sup_name, {__MODULE__, [host]})
    :ok
  end

  @doc """
  Start a new host directly. It's intended to be in use from the supervisor,
  but it could be used for test purposes.
  """
  @spec start_link([Hemdal.Config.Host.t()]) :: {:ok, pid()}
  def start_link([host]) do
    Logger.info("starting #{host.id} - #{host.name}")
    {:ok, _pid} = GenServer.start_link(__MODULE__, [host], name: via(host.id))
  end

  @doc """
  Check if the host is started based on the host ID passed as parameter.
  """
  @spec exists?(host_id()) :: boolean()
  def exists?(host_id) do
    pid = GenServer.whereis(via(host_id))
    is_pid(pid) and Process.alive?(pid)
  end

  @typedoc false
  @type host_id() :: String.t()

  @doc """
  Run or execute the command passed as parameter. It's needed to pass the host ID
  to find the process where to send the request, and the the command and the
  arguments to run the command.

  It's returning a tuple for `:ok` or `:error` and a set of data which depends on
  if it was success or not.

  The success return data is usually including the following keys (all of them as
  strings):

  - `status` which could be `OK`, `FAIL`, `WARN` or `UNKNOWN`.
  - `message` which is a string containing a message to show.

  The failure return data is usually similar to the previous one but it could be
  containing something different depending on the return of the remote command.
  If the JSON sent back from the command is valid, it's usually using that as
  data and it's marked as `UNKNOWN` status if there is no status defined.
  """
  @spec exec(host_id(), Hemdal.Config.Alert.Command.t(), command_args()) ::
          {:ok, map()} | {:error, map()}
  def exec(host_id, cmd, args) do
    GenServer.call(via(host_id), {:exec, cmd, args}, @timeout_exec)
  end

  @doc """
  Retrieve the PID providing the host ID.
  """
  @spec get_pid(host_id()) :: pid() | nil
  def get_pid(host_id) do
    GenServer.whereis(via(host_id))
  end

  @doc """
  Performs a reload for all of the hosts. It's retrieving the configuration for
  all of the hosts and applying it for each host. It's reloading the
  configuration for each host and applying it through the `update_host/1`
  function.
  """
  @spec reload_all() :: :ok
  def reload_all do
    Hemdal.Config.get_all_hosts()
    |> Enum.each(&update_host/1)
  end

  @doc """
  Start all of the hosts based on the configuration. It's retrieving all of
  the hosts from the configuration and the using each host with the `start/1`
  function.
  """
  @spec start_all() :: :ok
  def start_all do
    Hemdal.Config.get_all_hosts()
    |> Enum.each(&start/1)
  end

  @doc """
  Update the host configuration. If the host isn't running it's starting it
  and passing it the configuration provided as the `host` parameter. In a
  nutshell, it's: if exist host ID then perform an update of the host
  information, else start the process with the host information.
  """
  @spec update_host(Hemdal.Config.Host.t()) :: {:ok, pid()}
  def update_host(host) do
    if pid = get_pid(host.id) do
      GenStateMachine.cast(pid, {:update, host})
      {:ok, pid}
    else
      start(host)
    end
  end

  @type t() :: %__MODULE__{
          host: nil | Hemdal.Config.Host.t(),
          max_workers: :infinity | non_neg_integer(),
          workers: non_neg_integer(),
          queue: Queue.queue({GenServer.from(), command(), command_args()})
        }

  defstruct host: nil,
            max_workers: :infinity,
            workers: 0,
            queue: Queue.new()

  @impl GenServer
  @doc false
  def init([host]) do
    {:ok, %__MODULE__{host: host, max_workers: host.max_workers}}
  end

  @impl GenServer
  @doc false
  def handle_call({:exec, cmd, args}, from, %__MODULE__{max_workers: :infinity} = state) do
    Logger.debug(
      "host => workers: #{state.workers}/infinity ; queue length: #{Queue.len(state.queue)}"
    )

    spawn_monitor(fn -> run_in_background(cmd, args, from, state) end)
    {:noreply, %__MODULE__{state | workers: state.workers + 1}}
  end

  def handle_call(
        {:exec, cmd, args},
        from,
        %__MODULE__{max_workers: max_workers, workers: workers, queue: queue} = state
      )
      when workers >= max_workers do
    Logger.debug(
      "host => workers: #{workers}/#{max_workers} ; queue length: #{Queue.len(queue) + 1}"
    )

    {:noreply, %__MODULE__{state | queue: Queue.in({from, cmd, args}, queue)}}
  end

  def handle_call({:exec, cmd, args}, from, state) do
    spawn_monitor(fn -> run_in_background(cmd, args, from, state) end)
    workers = state.workers + 1

    Logger.debug(
      "host => workers: #{workers}/#{state.max_workers} ; queue length: #{Queue.len(state.queue)}"
    )

    {:noreply, %__MODULE__{state | workers: workers}}
  end

  @impl GenServer
  @doc false
  def handle_cast({:update, host}, state) do
    case {host.max_workers, state.host.max_workers} do
      {max_workers, max_workers} ->
        {:noreply, %__MODULE__{host: host}}

      {:infinity, _} ->
        {:noreply, %__MODULE__{host: host, max_workers: :infinity}}

      {new_max_workers, old_max_workers} when new_max_workers < old_max_workers ->
        {:noreply, %__MODULE__{host: host, max_workers: new_max_workers}}

      {new_max_workers, _old_max_workers} ->
        state =
          launch_extra(
            %__MODULE__{state | host: host, max_workers: new_max_workers},
            Queue.is_empty(state.queue)
          )

        {:noreply, state}
    end
  end

  defp launch_extra(state, true), do: state

  defp launch_extra(%__MODULE__{workers: max_workers, max_workers: max_workers} = state, false),
    do: state

  defp launch_extra(state, false) do
    {{:value, {from, cmd, args}}, queue} = Queue.out(state.queue)
    {:noreply, state} = handle_call({:exec, cmd, args}, from, %__MODULE__{state | queue: queue})
    launch_extra(state, Queue.is_empty(state.queue))
  end

  @impl GenServer
  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    case Queue.out(state.queue) do
      {:empty, _} ->
        workers = state.workers - 1
        Logger.debug("host => workers: #{workers}/#{state.max_workers} ; queue length: 0")
        {:noreply, %__MODULE__{state | workers: workers}}

      {{:value, {from, cmd, args}}, queue} ->
        state = %__MODULE__{state | queue: queue}
        spawn_monitor(fn -> run_in_background(cmd, args, from, state) end)

        Logger.debug(
          "host => workers: #{state.workers}/#{state.max_workers} ; queue length: #{Queue.len(queue)}"
        )

        {:noreply, state}
    end
  end

  defp run_result(data, 2, "FAIL"), do: {:error, Map.put(data, "status", "FAIL")}
  defp run_result(data, 1, "WARN"), do: {:error, Map.put(data, "status", "WARN")}
  defp run_result(data, 0, "OK"), do: {:ok, Map.put(data, "status", "OK")}
  defp run_result(data, _errorlevel, _status), do: {:error, Map.put(data, "status", "UNKNOWN")}

  defp final_run_result({:ok, %{"status" => "OK"} = data}), do: {:ok, data}

  defp final_run_result({:ok, %{} = result}),
    do: {:error, %{"status" => "UNKNOWN", "message" => "#{inspect(result)}"}}

  defp final_run_result({:error, error}) when is_binary(error),
    do: {:error, %{"message" => error, "status" => "UNKNOWN"}}

  defp final_run_result({:error, %{"status" => _} = error}), do: {:error, error}

  defp final_run_result({:error, error}),
    do: {:error, %{"message" => "#{inspect(error)}", "status" => "UNKNOWN"}}

  defp final_run_result(other) when not is_binary(other) do
    Logger.error("error => #{inspect(other)}")
    {:error, %{"message" => "#{inspect(other)}", "status" => "FAIL"}}
  end

  defp final_run_result(other) do
    Logger.error("error => #{other}")
    {:error, %{"message" => other, "status" => "FAIL"}}
  end

  defp run_in_background(cmd, args, from, %__MODULE__{host: %_{module: mod} = host}) do
    result =
      mod.transaction(host, fn handler ->
        with {:ok, errorlevel, output} <- exec_cmd(handler, mod, cmd, args),
             {:ok, %{"status" => status} = data} <- decode(output) do
          Logger.debug("command exit(#{errorlevel}) output: #{inspect(data)}")
          run_result(data, errorlevel, status)
        else
          other -> other
        end
      end)

    :ok = GenServer.reply(from, final_run_result(result))
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

  defp exec_cmd(handler, mod, %Command{type: "line", command: command}, _args) do
    mod.exec(handler, command)
  end

  defp exec_cmd(handler, mod, %Command{type: "script", command: script}, args) do
    tmp_file = Path.join([@default_temporal_dir, random_string()])

    try do
      sh =
        case String.split(script, ["\n"], trim: true) do
          ["#!" <> shell | _] -> shell
          _ -> @default_shell
        end

      mod.write_file(handler, tmp_file, script)
      cmd = Enum.join([sh, tmp_file | args], " ")
      mod.exec(handler, cmd)
    after
      mod.delete(handler, tmp_file)
    end
  end

  @typedoc """
  Handler is used by the backend implementation of the host, it could be
  whatever depending on the needs of the backend implementation. For
  example, it could be the SSH connection or the credentials, or the way
  to access to the PTY or TTY. See the implementations for further details.
  """
  @type handler() :: any

  @typedoc """
  The command to be executed.
  """
  @type command() :: String.t()

  @typedoc """
  The command arguments to be passed with the execution command.
  """
  @type command_args() :: [String.t()]

  @typedoc """
  The errorlevel is shell concept. In the shell every command is returning
  an integer as the errorlevel after the running, if that's 0 (zero), it's
  meaning the execution was fine, otherwise a positive or negative number
  means the running was wrong and the number could means something different
  depending on the command.
  """
  @type errorlevel() :: integer()

  @typedoc """
  The console output. It will be decoded using JSON to determine what's the
  information processed and generated by the command to be processed.
  """
  @type output() :: String.t()

  @typedoc """
  The reason of the failure. It's usually an atom, but it could be whatever.
  """
  @type reason() :: any

  @doc """
  The transaction is an optional callback which is implemented by default if
  you are using `use Hemdal.Host` and it's ensuring you can provide to the
  `write_file/3`, `exec/2` and `delete/2` the same handler which must be
  provided to the running function. As an example, the default implementation
  of this callback is as follows:

  ```elixir
  @impl Hemdal.Host
  def transaction(host, f), do: f.(host)
  ```
  """
  @callback transaction(Hemdal.Config.Host.t(), (handler() -> any)) :: any

  @doc """
  Exec a command using the method implemented by the module where it's
  implemented. The `exec/2` command is getting a handler from the transaction
  and the command to be executed as a string.
  """
  @callback exec(handler(), command()) :: {:ok, errorlevel(), output()} | {:error, reason()}

  @doc """
  Write a file in the remote (or local) host. It's intended to write the
  scripts which will be needed to be executed after that with `exec/2`.
  """
  @callback write_file(handler(), tmp_file :: String.t(), content :: String.t()) ::
              :ok | {:error, reason()}

  @doc """
  Remove a file which was created with `write_file/3` when the execution of
  the script was finalised.
  """
  @callback delete(handler(), tpm_file :: charlist()) :: :ok | {:error, reason()}

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Hemdal.Host

      @doc false
      @impl Hemdal.Host
      def transaction(host, f), do: f.(host)

      defoverridable transaction: 2
    end
  end
end
