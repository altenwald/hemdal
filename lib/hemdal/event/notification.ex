defmodule Hemdal.Event.Notification do
  @moduledoc """
  Consume events from `Hemdal.Event` to generate the notifications
  via `Hemdal.Notifier`. It's based on the configuration from the
  `Hemdal.Config.Notifier` module and based on the configuration
  for the `log_level` and the level of the event, it could be
  reported or not.

  The log levels could be:

  - `debug` it's reporting everything to the notifier.
  - `warn` notifies if the previous status is different from
    the new one.
  - `error` notifies only if the change is from/to error status.
  """
  use GenStage

  alias Hemdal.Config.Notifier

  @event_manager Hemdal.Event

  @doc false
  @spec start_link([]) :: {:ok, pid()}
  def start_link([]) do
    {:ok, _pid} = GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc false
  @spec stop() :: :ok
  def stop do
    GenStage.stop(__MODULE__)
  end

  @impl GenStage
  @doc false
  def init([]) do
    {:consumer, %{}, subscribe_to: [@event_manager]}
  end

  @impl true
  @doc false
  def handle_events(events, _from, state) do
    List.foldl(events, {:noreply, [], state}, fn
      event, {:noreply, [], state} -> process_event(event, state)
      _event, result -> result
    end)
  end

  defp check_log_level("debug", _, _), do: true
  defp check_log_level("error", :error, status) when status != :error, do: true
  defp check_log_level("error", prev, :error) when prev != :error, do: true
  defp check_log_level("error", _prev, _status), do: false
  defp check_log_level("warn", prev, status), do: prev != status

  defp check_log_level(level, prev, status) do
    raise """
    \n*******
    ERROR! The value for level (#{inspect(level)}) isn't valid!
    Check it out in your configuration and set: "warn", "error" or
    "debug".

    Previous status: #{prev}
    New status: #{status}
    """
  end

  def process_event(
        %{
          alert: alert,
          fail_duration: duration,
          status: status,
          metadata: metadata,
          prev_status: prev
        },
        state
      ) do
    alert.notifiers
    |> Enum.filter(&check_log_level(&1.log_level, prev, status))
    |> Enum.each(fn %Notifier{} = notifier ->
      Hemdal.Notifier.send(notifier, status, prev, alert, metadata, duration)
    end)

    {:noreply, [], state}
  end
end
