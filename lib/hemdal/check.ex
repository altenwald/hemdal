defmodule Hemdal.Check do
  @moduledoc """
  Every check performed by Hemdal is based on a state machine which is in
  charge of running a command, check the return and based on the return and
  if it was successfully executed or not, determine the state of the machine.

  The state machine has the following states:

  - `disabled`: it's not performing checks, it waits until it's activated.
  - `normal`: it's running correctly the command and always receiving a
    success state. It's configuring a state timeout based on `check_in_sec`
    from `Hemdal.Config.Alert`.
  - `failing`: when in `normal` state, it receives an failed response, it's
    moved to `failing` status. It's configuring a state timeout based on
    `recheck_in_sec` and if it's not recovering after a number of
    `retries` it's moving to `broken` (see `Hemdal.Config.Alert`).
  - `broken`: it was not running correctly for some time. We consider the
    subject under check broken and we are checking every
    `broken_recheck_in_sec` seconds. Only if it's recovered it back to
    `normal` state.
  """
  use GenStateMachine, callback_mode: :state_functions, restart: :transient
  require Logger

  alias Hemdal.Config.Alert
  alias Hemdal.Event
  alias Hemdal.Host

  @metadata_disabled %{"status" => "OFF", "message" => "disabled"}

  @supervisor Hemdal.Check.Supervisor

  @typedoc """
  The status available inside of the events. It's valid for both,
  current and previous state.
  """
  @type status() :: :ok | :warn | :error | :disabled

  @doc false
  @spec start(Hemdal.Config.Alert.t()) :: {:ok, pid()}
  def start(alert) do
    {:ok, _pid} = DynamicSupervisor.start_child(@supervisor, {__MODULE__, [alert]})
  end

  @doc false
  @spec start_link([Hemdal.Config.Alert.t()]) :: {:ok, pid()}
  def start_link([alert]) do
    {:ok, _pid} = GenStateMachine.start_link(__MODULE__, [alert], name: via(alert.id))
  end

  @doc false
  @spec stop(pid() | alert_id()) :: :ok
  def stop(pid) when is_pid(pid) do
    GenStateMachine.stop(pid)
  end

  def stop(alert_id) do
    GenStateMachine.stop(via(alert_id))
  end

  @typedoc """
  The alert ID in use to identify the state machine running the checks for the alert.
  """
  @type alert_id() :: String.t()

  @doc """
  Check if the alert is running.
  """
  @spec exists?(alert_id()) :: boolean()
  def exists?(alert_id) do
    !!get_pid(alert_id)
  end

  @doc """
  Returns the PID of the alert process if it's running.
  """
  @spec get_pid(alert_id()) :: pid() | nil
  def get_pid(alert_id) do
    GenServer.whereis(via(alert_id))
  end

  @doc """
  Reload all of the alerts based on the configuration backend. See
  `Hemdal.Config` for further information. If the alert isn't running
  it's starting it.
  """
  @spec reload_all() :: :ok
  def reload_all do
    Hemdal.Config.get_all_alerts()
    |> Enum.each(&update_alert/1)
  end

  @doc """
  Ensure all of the alerts are started.
  """
  @spec start_all() :: :ok
  def start_all do
    Hemdal.Config.get_all_alerts()
    |> Enum.each(&start/1)
  end

  @doc """
  Get all of the alerts running. It's requesting to the supervisor the list
  of all of the alerts and it's gathering the status for each one based on
  the `get_status/1` function.
  """
  @spec get_all() :: [returned_status()]
  def get_all do
    DynamicSupervisor.which_children(Hemdal.Check.Supervisor)
    |> Enum.map(fn {_, pid, _, _} ->
      Task.async(fn -> get_status(pid) end)
    end)
    |> Enum.map(&Task.await(&1))
  end

  @doc """
  Get the status of an alert. It's requesting the status directly to the
  process.
  """
  @spec get_status(pid() | alert_id()) :: [returned_status()]
  def get_status(pid) when is_pid(pid) do
    GenStateMachine.call(pid, :get_status)
  end

  def get_status(alert_id) do
    GenStateMachine.call(via(alert_id), :get_status)
  end

  @doc """
  Update the alert passing the new configuration to the process. It's
  useful when we want to change the configuration for the command, the
  host or whatever else inside of the alert/check.
  """
  @spec update_alert(Hemdal.Config.Alert.t()) :: {:ok, pid()}
  def update_alert(alert) do
    if pid = get_pid(alert.id) do
      GenStateMachine.cast(pid, {:update, alert})
      {:ok, pid}
    else
      start(alert)
    end
  end

  @type t() :: %__MODULE__{
          alert: Hemdal.Config.Alert.t() | nil,
          status: returned_status() | nil,
          retries: non_neg_integer(),
          last_update: NaiveDateTime.t(),
          fail_started: NaiveDateTime.t() | nil
        }

  defstruct alert: nil,
            status: nil,
            retries: 0,
            last_update: NaiveDateTime.utc_now(),
            fail_started: nil

  defp via(name) do
    {:via, Registry, {Hemdal.Check.Registry, name}}
  end

  @impl GenStateMachine
  @doc false
  def init([alert]) do
    state = %__MODULE__{alert: alert, last_update: NaiveDateTime.utc_now()}

    if alert.enabled do
      {:ok, :normal, state, [{:next_event, :state_timeout, :check}]}
    else
      {:ok, :disabled, state}
    end
  end

  @impl GenStateMachine
  @doc false
  def code_change(_old_vsn, state_name, state_data, _extra) do
    {:ok, state_name, state_data}
  end

  @typedoc """
  The returned status retrieved from the process is built to contain a map with
  keys which are strings and the content which could be different depending
  on the key. The keys are the following ones:

  - `status` is an atom and it could be `:ok`, `:disabled`, `:warn` or
    `:error`.
  - `alert` is a map which is including information for the alert itself,
    information like: id, name, host, and command.
  - `last_update` is a naive datetime generated at the moment.
  - `result` is a map with information of the executed command.
  """
  @type returned_status() :: map()

  defp build_reply(type, %__MODULE__{alert: alert, status: status} = state) do
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

  @doc false
  def disabled({:call, from}, :get_status, state) do
    reply = build_reply(:disabled, %__MODULE__{state | status: @metadata_disabled})
    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def disabled(:cast, {:update, %Alert{enabled: false} = alert}, state) do
    state = %__MODULE__{state | alert: alert, last_update: NaiveDateTime.utc_now()}
    {:keep_state, state}
  end

  def disabled(:cast, {:update, %Alert{} = alert}, state) do
    state = %__MODULE__{state | alert: alert}
    actions = [{:next_event, :state_timeout, :check}]
    {:next_state, :normal, state, actions}
  end

  @doc false
  def normal({:call, from}, :get_status, state) do
    reply = build_reply(:ok, state)
    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def normal(:cast, {:update, %Alert{enabled: false} = alert}, state) do
    state = %__MODULE__{state | alert: alert, last_update: NaiveDateTime.utc_now()}

    Event.notify(%Event{
      alert: alert,
      status: :disabled,
      prev_status: :ok,
      fail_duration: 0,
      last_update: NaiveDateTime.utc_now(),
      metadata: @metadata_disabled
    })

    {:next_state, :disabled, state}
  end

  def normal(:cast, {:update, alert}, state) do
    {:keep_state, %__MODULE__{state | alert: alert, last_update: NaiveDateTime.utc_now()}}
  end

  def normal(:state_timeout, :check, %__MODULE__{alert: %Alert{} = alert} = state) do
    case perform_check(alert) do
      {:ok, status} ->
        Event.notify(%Event{
          alert: alert,
          status: :ok,
          prev_status: :ok,
          fail_started: NaiveDateTime.utc_now(),
          fail_duration: 0,
          last_update: NaiveDateTime.utc_now(),
          metadata: status
        })

        timeout = alert.check_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
        state = %__MODULE__{state | status: status, last_update: NaiveDateTime.utc_now()}
        {:keep_state, state, actions}

      {:error, error} ->
        failed_started = NaiveDateTime.utc_now()

        Event.notify(%Event{
          alert: alert,
          status: :warn,
          prev_status: :ok,
          fail_started: failed_started,
          fail_duration: 0,
          last_update: NaiveDateTime.utc_now(),
          metadata: error
        })

        Logger.warning(
          "[#{alert.id}] starting to fail [#{alert.name}] for " <>
            "[#{alert.host.name}]: #{inspect(error)}"
        )

        timeout = alert.recheck_in_sec * 1_000

        state = %__MODULE__{
          state
          | status: error,
            retries: alert.retries,
            fail_started: failed_started,
            last_update: NaiveDateTime.utc_now()
        }

        actions = [{:state_timeout, timeout, :check}]
        {:next_state, :failing, state, actions}
    end
  end

  defp ellapsed(previous) do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), previous)
  end

  @doc false
  def failing({:call, from}, :get_status, state) do
    reply = build_reply(:warn, state)
    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def failing(:cast, {:update, %Alert{enabled: false} = alert}, state) do
    state = %__MODULE__{state | alert: alert, last_update: NaiveDateTime.utc_now()}
    t = ellapsed(state.fail_started)

    Event.notify(%Event{
      alert: alert,
      status: :disabled,
      prev_status: :warn,
      fail_started: state.fail_started,
      fail_duration: t,
      last_update: NaiveDateTime.utc_now(),
      metadata: @metadata_disabled
    })

    {:next_state, :disabled, state}
  end

  def failing(:cast, {:update, alert}, state) do
    {:keep_state, %__MODULE__{state | alert: alert}}
  end

  def failing(:state_timeout, :check, %__MODULE__{alert: alert, retries: retries} = state)
      when retries <= 1 do
    case perform_check(alert) do
      {:ok, status} ->
        t = ellapsed(state.fail_started)
        now = NaiveDateTime.utc_now()

        Event.notify(%Event{
          alert: alert,
          status: :ok,
          prev_status: :warn,
          fail_started: state.fail_started,
          fail_duration: t,
          last_update: now,
          metadata: status
        })

        timeout = alert.check_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
        state = %__MODULE__{state | status: status, last_update: now}
        {:next_state, :normal, state, actions}

      {:error, error} ->
        t = ellapsed(state.fail_started)
        now = NaiveDateTime.utc_now()

        Event.notify(%Event{
          alert: alert,
          status: :error,
          prev_status: :warn,
          fail_started: state.fail_started,
          fail_duration: t,
          last_update: now,
          metadata: error
        })

        Logger.error("[#{alert.id}] confirmed fail [#{alert.name}] for [#{alert.host.name}] [#{t} sec]")

        timeout = alert.broken_recheck_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
        state = %__MODULE__{state | status: error, last_update: now}
        {:next_state, :broken, state, actions}
    end
  end

  def failing(:state_timeout, :check, %__MODULE__{alert: alert} = state) do
    case perform_check(alert) do
      {:ok, status} ->
        t = ellapsed(state.fail_started)
        now = NaiveDateTime.utc_now()

        Event.notify(%Event{
          alert: alert,
          status: :ok,
          prev_status: :warn,
          fail_started: state.fail_started,
          fail_duration: t,
          last_update: now,
          metadata: status
        })

        timeout = alert.check_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
        state = %__MODULE__{state | status: status, last_update: now}
        {:next_state, :normal, state, actions}

      {:error, error} ->
        t = ellapsed(state.fail_started)
        now = NaiveDateTime.utc_now()

        Event.notify(%Event{
          alert: alert,
          status: :warn,
          prev_status: :warn,
          fail_started: state.fail_started,
          fail_duration: t,
          last_update: now,
          metadata: error
        })

        timeout = alert.recheck_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]

        state = %__MODULE__{
          state
          | retries: state.retries - 1,
            last_update: now
        }

        {:keep_state, state, actions}
    end
  end

  @doc false
  def broken({:call, from}, :get_status, state) do
    reply = build_reply(:error, state)
    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  def broken(:cast, {:update, %Alert{enabled: false} = alert}, state) do
    state = %__MODULE__{state | alert: alert, last_update: NaiveDateTime.utc_now()}
    t = ellapsed(state.fail_started)
    now = NaiveDateTime.utc_now()

    Event.notify(%Event{
      alert: alert,
      status: :disabled,
      prev_status: :error,
      fail_started: state.fail_started,
      fail_duration: t,
      last_update: now,
      metadata: @metadata_disabled
    })

    {:next_state, :disabled, state}
  end

  def broken(:cast, {:update, alert}, state) do
    {:keep_state, %__MODULE__{state | alert: alert, last_update: NaiveDateTime.utc_now()}}
  end

  def broken(:state_timeout, :check, %__MODULE__{alert: alert} = state) do
    case perform_check(alert) do
      {:ok, status} ->
        t = ellapsed(state.fail_started)
        now = NaiveDateTime.utc_now()

        Event.notify(%Event{
          alert: alert,
          status: :ok,
          prev_status: :error,
          fail_started: state.fail_started,
          fail_duration: t,
          last_update: now,
          metadata: status
        })

        Logger.info("[#{alert.id}] recover [#{alert.name}] for [#{alert.host.name}] [#{t} sec]")

        timeout = alert.check_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
        state = %__MODULE__{state | status: status, last_update: now}
        {:next_state, :normal, state, actions}

      {:error, error} ->
        t = ellapsed(state.fail_started)
        now = NaiveDateTime.utc_now()

        Event.notify(%Event{
          alert: alert,
          status: :error,
          prev_status: :error,
          fail_started: state.fail_started,
          fail_duration: t,
          last_update: now,
          metadata: error
        })

        timeout = alert.broken_recheck_in_sec * 1_000
        actions = [{:state_timeout, timeout, :check}]
        state = %__MODULE__{state | status: error, last_update: now}
        {:keep_state, state, actions}
    end
  end

  defp perform_check(alert) do
    Logger.debug(
      "[#{alert.id}] performing check [#{alert.name}] against " <>
        "[#{alert.host.name}] using [#{alert.command.name}]"
    )

    if Host.exists?(alert.host.id) do
      Host.exec(alert.host.id, alert.command, alert.command_args)
    else
      Host.start(alert.host)
      Host.exec(alert.host.id, alert.command, alert.command_args)
    end
  end
end
