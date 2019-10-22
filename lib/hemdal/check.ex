defmodule Hemdal.Check do
  use GenStateMachine, callback_mode: :state_functions, restart: :transient
  require Logger

  alias Hemdal.{Alert, EventManager}
  alias Hemdal.Host.Conn

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
                  Task.async(fn -> get_status(pid) end)
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
    defstruct alert: nil,
              status: nil,
              retries: 0,
              last_update: NaiveDateTime.utc_now(),
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
        "host" => alert.host.description || alert.host.name,
        "command" => alert.command.name,
        "group" => %{
          "name" => alert.group.name,
          "id" => alert.group_id,
        }
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
                          metadata: %{"message" => "disabled"}})
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
        timeout = alert.check_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
        state = %State{state | status: status,
                               last_update: NaiveDateTime.utc_now()}
        {:keep_state, state, actions}
      {:error, error} ->
        EventManager.notify(%{alert: alert,
                              status: :warn,
                              prev_status: :ok,
                              fail_started: 0,
                              last_update: NaiveDateTime.utc_now(),
                              metadata: %{"message" => error}})
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
                          metadata: %{"message" => "disabled"}})
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
        timeout = alert.check_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
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
                              metadata: %{"message" => error}})
        Logger.error "[#{alert.id}] confirmed fail [#{alert.name}]" <>
                     " for [#{alert.host.name}] " <>
                     "[#{ellapsed(state.fail_started)} sec]"
        timeout = alert.broken_recheck_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
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
        timeout = alert.check_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
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
                              metadata: %{"message" => error}})
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
                          metadata: %{"message" => "disabled"}})
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
        timeout = alert.check_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
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
                              metadata: %{"message" => error}})
        timeout = alert.broken_recheck_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
        state = %State{state | status: error,
                               last_update: NaiveDateTime.utc_now()}
        {:keep_state, state, actions}
    end
  end

  defp perform_check(alert) do
    Logger.debug "[#{alert.id}] performing check [#{alert.name}] against " <>
                 "[#{alert.host.name}] using [#{alert.command.name}]"
    if Conn.exists?(alert.host.id) do
      Conn.exec(alert.host.id, alert.command, alert.command_args)
    else
      Conn.start(alert.host)
      Conn.exec(alert.host.id, alert.command, alert.command_args)
    end
  end
end
