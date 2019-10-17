defmodule Hemdal.Check do
  use GenStateMachine, callback_mode: :state_functions, restart: :transient
  require Logger

  @temporal_dir "/tmp"
  @default_shell "/bin/bash"

  alias Hemdal.{Alert, Command, EventManager}

  def start(alert) do
    DynamicSupervisor.start_child Hemdal.Check.Supervisor,
                                  {__MODULE__, [alert]}
  end

  def start_link([alert]) do
    GenStateMachine.start_link __MODULE__, [alert], name: via(alert.id)
  end

  def stop(pid) when is_pid(pid) do
    GenStateMachine.stop(pid)
  end
  def stop(name) do
    GenStateMachine.stop(via(name))
  end

  def exists?(name) do
    case Registry.lookup(Hemdal.Check.Registry, name) do
      [{_pid, nil}] -> true
      [] -> false
    end
  end

  def get_pid(name) do
    case Registry.lookup(Hemdal.Check.Registry, name) do
      [{pid, nil}] -> pid
      [] -> nil
    end
  end

  def reload_all do
    Alert.get_all()
    |> Enum.each(&(update_alert(&1)))
  end

  def get_all do
    DynamicSupervisor.which_children(Hemdal.Check.Supervisor)
    |> Enum.map(fn {_, pid, _, _} ->
                  Task.async(fn ->
                    GenStateMachine.call(pid, :get_status)
                  end)
                end)
    |> Enum.map(&(Task.await(&1)))
  end

  def get_status(pid) when is_pid(pid) do
    GenStateMachine.call pid, :get_status
  end
  def get_status(name) do
    GenStateMachine.call via(name), :get_status
  end

  def update_alert(alert) do
    if exists?(alert.id) do
      GenStateMachine.cast via(alert.id), {:update, alert}
      {:ok, get_pid(alert.id)}
    else
      start(alert)
    end
  end

  defmodule State do
    @time_to_check 60_000
    @time_to_check_broken 10_000

    defstruct alert: nil,
              status: nil,
              retries: 0,
              last_update: NaiveDateTime.utc_now(),
              time_to_check: @time_to_check,
              time_to_check_broken: @time_to_check_broken,
              fail_started: nil
  end

  defp via(name) do
    {:via, Registry, {Hemdal.Check.Registry, name}}
  end

  @impl GenStateMachine
  def init([alert]) do
    state = %State{alert: alert,
                   last_update: NaiveDateTime.utc_now()}
    ## FIXME retrieve initial state name from alert (logs)
    if alert.enabled do
      {:ok, :normal, state, [{:next_event, :state_timeout, :check}]}
    else
      {:ok, :disabled, state}
    end
  end

  @impl GenStateMachine
  def code_change(_old_vsn, state_name, state_data, _extra) do
    {:ok, state_name, state_data}
  end

  defp build_reply(type, %State{alert: alert, status: status} = state) do
    %{
      "status" => type,
      "alert" => %{
        "id" => alert.id,
        "name" => alert.name,
        "host" => alert.host.name,
        "command" => alert.command.name
      },
      "last_update" => state.last_update,
      "result" => status
    }
  end

  def disabled({:call, from}, :get_status, state) do
    reply = build_reply(:disabled, state)
    {:keep_state_and_data, [{:reply, from, reply}]}
  end
  def disabled(:cast, {:update, %Alert{enabled: false} = alert}, state) do
    state = %State{state | alert: alert, last_update: NaiveDateTime.utc_now()}
    {:keep_state, state}
  end
  def disabled(:cast, {:update, alert}, state) do
    state = %State{state | alert: alert}
    actions = [{:next_event, :state_timeout, :check}]
    {:next_state, :normal, state, actions}
  end

  def normal({:call, from}, :get_status, state) do
    reply = build_reply(:ok, state)
    {:keep_state_and_data, [{:reply, from, reply}]}
  end
  def normal(:cast, {:update, %Alert{enabled: false} = alert}, state) do
    state = %State{state | alert: alert, last_update: NaiveDateTime.utc_now()}
    EventManager.notify(%{alert: alert,
                          status: :disabled,
                          prev_status: :ok,
                          fail_started: 0,
                          last_update: NaiveDateTime.utc_now(),
                          metadata: "disabled"})
    {:next_state, :disabled, state}
  end
  def normal(:cast, {:update, alert}, state) do
    {:keep_state, %State{state | alert: alert,
                                 last_update: NaiveDateTime.utc_now()}}
  end
  def normal(:state_timeout, :check, %State{alert: alert} = state) do
    case perform_check(alert) do
      {:ok, status} ->
        EventManager.notify(%{alert: alert,
                              status: :ok,
                              prev_status: :ok,
                              fail_started: 0,
                              last_update: NaiveDateTime.utc_now(),
                              metadata: status})
        actions = [{:state_timeout, state.time_to_check, :check}]
        state = %State{state | status: status,
                               last_update: NaiveDateTime.utc_now()}
        {:keep_state, state, actions}
      {:error, error} ->
        EventManager.notify(%{alert: alert,
                              status: :warn,
                              prev_status: :ok,
                              fail_started: 0,
                              last_update: NaiveDateTime.utc_now(),
                              metadata: %{"error" => error}})
        Logger.warn "[#{alert.id}] starting to fail [#{alert.name}] for " <>
                    "[#{alert.host.name}]: #{inspect error}"
        timeout = alert.recheck_in_sec * 1_000
        state = %State{state | status: error,
                               retries: alert.retries,
                               fail_started: NaiveDateTime.utc_now(),
                               last_update: NaiveDateTime.utc_now()}
        actions = [{:state_timeout, timeout, :check}]
        {:next_state, :failing, state, actions}
    end
  end

  defp ellapsed(previous) do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), previous)
  end

  def failing({:call, from}, :get_status, state) do
    reply = build_reply(:warn, state)
    {:keep_state_and_data, [{:reply, from, reply}]}
  end
  def failing(:cast, {:update, %Alert{enabled: false} = alert}, state) do
    state = %State{state | alert: alert, last_update: NaiveDateTime.utc_now()}
    t = ellapsed(state.fail_started)
    EventManager.notify(%{alert: alert,
                          status: :disabled,
                          prev_status: :warn,
                          fail_started: t,
                          last_update: NaiveDateTime.utc_now(),
                          metadata: "disabled"})
    {:next_state, :disabled, state}
  end
  def failing(:cast, {:update, alert}, state) do
    {:keep_state, %State{state | alert: alert}}
  end
  def failing(:state_timeout, :check,
              %State{alert: alert, retries: retries} = state)
    when retries <= 1 do
    case perform_check(alert) do
      {:ok, status} ->
        t = ellapsed(state.fail_started)
        EventManager.notify(%{alert: alert,
                              status: :ok,
                              prev_status: :warn,
                              fail_started: t,
                              last_update: NaiveDateTime.utc_now(),
                              metadata: status})
        actions = [{:state_timeout, state.time_to_check, :check}]
        state = %State{state | status: status,
                               last_update: NaiveDateTime.utc_now()}
        {:next_state, :normal, state, actions}
      {:error, error} ->
        t = ellapsed(state.fail_started)
        EventManager.notify(%{alert: alert,
                              status: :error,
                              prev_status: :warn,
                              fail_started: t,
                              last_update: NaiveDateTime.utc_now(),
                              metadata: %{"error" => error}})
        Logger.error "[#{alert.id}] confirmed fail [#{alert.name}]" <>
                     " for [#{alert.host.name}] " <>
                     "[#{ellapsed(state.fail_started)} sec]"
        actions = [{:state_timeout, state.time_to_check_broken, :check}]
        state = %State{state | status: error,
                               last_update: NaiveDateTime.utc_now()}
        {:next_state, :broken, state, actions}
    end
  end
  def failing(:state_timeout, :check, %State{alert: alert} = state) do
    case perform_check(alert) do
      {:ok, status} ->
        t = ellapsed(state.fail_started)
        EventManager.notify(%{alert: alert,
                              status: :ok,
                              prev_status: :warn,
                              fail_started: t,
                              last_update: NaiveDateTime.utc_now(),
                              metadata: status})
        actions = [{:state_timeout, state.time_to_check, :check}]
        state = %State{state | status: status,
                               last_update: NaiveDateTime.utc_now()}
        {:next_state, :normal, state, actions}
      {:error, error} ->
        t = ellapsed(state.fail_started)
        EventManager.notify(%{alert: alert,
                              status: :warn,
                              prev_status: :warn,
                              fail_started: t,
                              last_update: NaiveDateTime.utc_now(),
                              metadata: %{"error" => error}})
        timeout = alert.recheck_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
        state = %State{state | retries: state.retries - 1,
                               last_update: NaiveDateTime.utc_now()}
        {:keep_state, state, actions}
    end
  end

  def broken({:call, from}, :get_status, state) do
    reply = build_reply(:error, state)
    {:keep_state_and_data, [{:reply, from, reply}]}
  end
  def broken(:cast, {:update, %Alert{enabled: false} = alert}, state) do
    state = %State{state | alert: alert, last_update: NaiveDateTime.utc_now()}
    t = ellapsed(state.fail_started)
    EventManager.notify(%{alert: alert,
                          status: :disabled,
                          prev_status: :error,
                          fail_started: t,
                          last_update: NaiveDateTime.utc_now(),
                          metadata: "disabled"})
    {:next_state, :disabled, state}
  end
  def broken(:cast, {:update, alert}, state) do
    {:keep_state, %State{state | alert: alert,
                                 last_update: NaiveDateTime.utc_now()}}
  end
  def broken(:state_timeout, :check, %State{alert: alert} = state) do
    case perform_check(alert) do
      {:ok, status} ->
        t = ellapsed(state.fail_started)
        EventManager.notify(%{alert: alert,
                              status: :ok,
                              prev_status: :error,
                              fail_started: t,
                              last_update: NaiveDateTime.utc_now(),
                              metadata: status})
        Logger.info "[#{alert.id}] recover [#{alert.name}] for " <>
                    "[#{alert.host.name}] " <>
                    "[#{ellapsed(state.fail_started)} sec]"
        actions = [{:state_timeout, state.time_to_check, :check}]
        state = %State{state | status: status,
                               last_update: NaiveDateTime.utc_now()}
        {:next_state, :normal, state, actions}
      {:error, error} ->
        t = ellapsed(state.fail_started)
        EventManager.notify(%{alert: alert,
                              status: :error,
                              prev_status: :error,
                              fail_started: t,
                              last_update: NaiveDateTime.utc_now(),
                              metadata: %{"error" => error}})
        actions = [{:state_timeout, state.time_to_check_broken, :check}]
        state = %State{state | status: error,
                               last_update: NaiveDateTime.utc_now()}
        {:keep_state, state, actions}
    end
  end

  defp perform_check(alert) do
    Logger.debug "[#{alert.id}] performing check [#{alert.name}] against " <>
                 "[#{alert.host.name}] using [#{alert.command.name}]"
    opts = [host: String.to_charlist(alert.host.name),
            port: alert.host.port,
            user: String.to_charlist(alert.host.username),
            id_rsa: alert.host.access_key]
    result = :trooper_ssh.transaction(opts, fn(trooper) ->
      with {:ok, 0, output} <- exec_cmd(trooper, alert),
           {:ok, %{"status" => "OK"} = data} <- decode(output) do
        :trooper_ssh.stop(trooper)
        Logger.debug("data: #{inspect data}")
        {:ok, data}
      else
        other -> other
      end
    end)
    case result do
      {:ok, %{"status" => "OK"} = data} -> {:ok, data}
      {:error, error} -> {:error, "#{inspect error}"}
      {:ok, %{} = result} -> {:error, result}
      {:ok, errorlevel, error} ->
        {:error, %{"errorlevel" => errorlevel,
                   "message" => error,
                   "status" => "FAIL"}}
      other ->
        Logger.error("error => #{inspect other}")
        {:error, "#{inspect other}"}
    end
  end

  defp decode(output) do
    case Jason.decode(output) do
      {:ok, [status, message]} ->
        {:ok, %{"status" => status, "description" => message}}
      other_resp -> other_resp
    end
  end

  defp random_string do
    Integer.to_string(:rand.uniform(0x100000000), 36) |> String.downcase
  end

  defp exec_cmd(trooper, %Alert{command: %Command{command_type: "line",
                                                  command: command}}) do
    :trooper_ssh.exec(trooper, command)
  end
  defp exec_cmd(trooper, %Alert{command: %Command{command_type: "script",
                                                  command: script},
                                command_args: args}) do
    tmp_file = Path.join([@temporal_dir, random_string()])
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
end
