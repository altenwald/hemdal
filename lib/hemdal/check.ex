defmodule Hemdal.Check do
  use GenStateMachine, callback_mode: :state_functions
  require Logger

  alias Hemdal.EventManager

  def start(alert) do
    DynamicSupervisor.start_child Hemdal.Check.Supervisor,
                                  {__MODULE__, [alert]}
  end

  def start_link([alert]) do
    GenStateMachine.start_link __MODULE__, [alert], name: via(alert.id)
  end

  def exists?(name) do
    case Registry.lookup(Hemdal.Check.Registry, name) do
      [{_pid, nil}] -> true
      [] -> false
    end
  end

  def get_all do
    DynamicSupervisor.which_children(Hemdal.Check.Supervisor)
    |> Enum.map(fn {_, pid, _, _} ->
                  GenStateMachine.call(pid, :get_status)
                end)
  end

  def get_status(name) when is_binary(name) do
    GenStateMachine.call via(name), :get_status
  end
  def get_status(pid) when is_pid(pid) do
    GenStateMachine.call pid, :get_status
  end

  def update_alert(alert) do
    if exists?(alert.id) do
      GenStateMachine.cast via(alert.id), {:update, alert}
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
              time_to_check: @time_to_check,
              time_to_check_broken: @time_to_check_broken,
              fail_started: nil
  end

  defp via(name) do
    {:via, Registry, {Hemdal.Check.Registry, name}}
  end

  @impl GenStateMachine
  def init([alert]) do
    state = %State{alert: alert}
    ## FIXME retrieve initial state name from alert (logs)
    {:ok, :normal, state, [{:next_event, :state_timeout, :check}]}
  end

  @impl GenStateMachine
  def code_change(_old_vsn, state_name, state_data, _extra) do
    {:ok, state_name, state_data}
  end

  def normal({:call, from}, :get_status,
             %State{alert: alert, status: status}) do
    reply = %{"status" => :ok,
              "alert" => %{
                "name" => alert.name,
                "host" => alert.host.name,
                "command" => alert.command.name
              },
              "result" => status}
    {:keep_state_and_data, [{:reply, from, reply}]}
  end
  def normal(:cast, {:update, alert}, state) do
    {:keep_state, %State{state | alert: alert}}
  end
  def normal(:state_timeout, :check, %State{alert: alert} = state) do
    case perform_check(alert) do
      {:ok, status} ->
        EventManager.notify(%{alert: alert,
                              status: :ok,
                              prev_status: :ok,
                              fail_started: 0,
                              metadata: status})
        actions = [{:state_timeout, state.time_to_check, :check}]
        {:keep_state, %State{state | status: status}, actions}
      {:error, error} ->
        EventManager.notify(%{alert: alert,
                              status: :warn,
                              prev_status: :ok,
                              fail_started: 0,
                              metadata: %{"error" => error}})
        Logger.warn "[#{alert.id}] starting to fail [#{alert.name}] for " <>
                    "[#{alert.host.name}]: #{inspect error}"
        timeout = alert.recheck_in_sec * 1_000
        state = %State{state | status: error,
                               retries: alert.retries,
                               fail_started: NaiveDateTime.utc_now()}
        actions = [{:state_timeout, timeout, :check}]
        {:next_state, :failing, state, actions}
    end
  end

  defp ellapsed(previous) do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), previous)
  end

  def failing({:call, from}, :get_status,
              %State{alert: alert, status: status}) do
    reply = %{"status" => :warn,
              "alert" => %{
                "name" => alert.name,
                "host" => alert.host.name,
                "command" => alert.command.name
              },
              "result" => status}
    {:keep_state_and_data, [{:reply, from, reply}]}
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
                              metadata: status})
        actions = [{:state_timeout, state.time_to_check, :check}]
        state = %State{state | status: status}
        {:next_state, :normal, state, actions}
      {:error, error} ->
        t = ellapsed(state.fail_started)
        EventManager.notify(%{alert: alert,
                              status: :error,
                              prev_status: :warn,
                              fail_started: t,
                              metadata: %{"error" => error}})
        Logger.error "[#{alert.id}] confirmed fail [#{alert.name}]" <>
                     " for [#{alert.host.name}] " <>
                     "[#{ellapsed(state.fail_started)} sec]"
        actions = [{:state_timeout, state.time_to_check_broken, :check}]
        state = %State{state | status: error}
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
                              metadata: status})
        actions = [{:state_timeout, state.time_to_check, :check}]
        state = %State{state | status: status}
        {:next_state, :normal, state, actions}
      {:error, error} ->
        t = ellapsed(state.fail_started)
        EventManager.notify(%{alert: alert,
                              status: :warn,
                              prev_status: :warn,
                              fail_started: t,
                              metadata: %{"error" => error}})
        timeout = alert.recheck_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
        state = %State{state | retries: state.retries - 1}
        {:keep_state, state, actions}
    end
  end

  def broken({:call, from}, :get_status,
             %State{alert: alert, status: status}) do
    reply = %{"status" => :error,
              "alert" => %{
                "name" => alert.name,
                "host" => alert.host.name,
                "command" => alert.command.name
              },
              "result" => status}
    {:keep_state_and_data, [{:reply, from, reply}]}
  end
  def broken(:cast, {:update, alert}, state) do
    {:keep_state, %State{state | alert: alert}}
  end
  def broken(:state_timeout, :check, %State{alert: alert} = state) do
    case perform_check(alert) do
      {:ok, status} ->
        t = ellapsed(state.fail_started)
        EventManager.notify(%{alert: alert,
                              status: :ok,
                              prev_status: :error,
                              fail_started: t,
                              metadata: status})
        Logger.info "[#{alert.id}] recover [#{alert.name}] for " <>
                    "[#{alert.host.name}] " <>
                    "[#{ellapsed(state.fail_started)} sec]"
        actions = [{:state_timeout, state.time_to_check, :check}]
        state = %State{state | status: status}
        {:next_state, :normal, state, actions}
      {:error, error} ->
        t = ellapsed(state.fail_started)
        EventManager.notify(%{alert: alert,
                              status: :error,
                              prev_status: :error,
                              fail_started: t,
                              metadata: %{"error" => error}})
        actions = [{:state_timeout, state.time_to_check_broken, :check}]
        state = %State{state | status: error}
        {:keep_state, state, actions}
    end
  end

  defp perform_check(alert) do
    Logger.debug "[#{alert.id}] performing check [#{alert.name}] against " <>
                 "[#{alert.host.name}] using [#{alert.command.name}]"
    opts = [host: String.to_charlist(alert.host.name),
            user: String.to_charlist(alert.host.username),
            id_rsa: alert.host.access_key]
    command = alert.command.command
    with {:ok, trooper} <- :trooper_ssh.start(opts),
         {:ok, 0, output} <- :trooper_ssh.exec(trooper, command),
         {:ok, %{"status" => "OK"} = data} <- Jason.decode(output) do
      :trooper_ssh.stop(trooper)
      Logger.debug("data: #{inspect data}")
      {:ok, data}
    else
      {:error, error} ->
        {:error, "#{inspect error}"}
      {:ok, %{} = result} ->
        {:error, result}
      other ->
        Logger.error("error => #{inspect other}")
        {:error, "#{inspect other}"}
    end
  end
end
