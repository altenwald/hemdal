defmodule Hemdal.Event.Log do
  use GenStage
  require Logger

  @event_manager Hemdal.Event

  def start_link([]) do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def stop do
    GenStage.stop(__MODULE__)
  end

  @impl GenStage
  def init([]) do
    state = %{log_level: Application.get_env(:hemdal, :log_level, "warn")}
    {:consumer, state, subscribe_to: [@event_manager]}
  end

  @impl true
  def handle_events(events, _from, state) do
    Enum.each(events, &process_event(&1, state.log_level))
    {:noreply, [], state}
  end

  def process_event(%{status: status, prev_status: prev}, "error")
      when not (status == "FAIL" and prev != "FAIL") and
             not (status != "FAIL" and prev == "FAIL") do
    :ok
  end

  def process_event(%{status: status, prev_status: status}, "warn"), do: :ok

  def process_event(event, _log_level) do
    message = get_message(event, event.status, event.prev_status)

    case event.status do
      :ok -> Logger.info(message)
      :warn -> Logger.warn(message)
      :error -> Logger.error(message)
    end

    :ok
  end

  defp get_message(event, :disabled, _) do
    "disabled #{event.alert.name} on #{event.alert.host.name}"
  end

  defp get_message(event, :ok, :ok) do
    "sucessful run #{event.alert.name} on #{event.alert.host.name}"
  end

  defp get_message(event, :ok, :warn) do
    "sucessful again run #{event.alert.name} on #{event.alert.host.name} after #{event[:duration] || "unknown"} sec"
  end

  defp get_message(event, :ok, :error) do
    "recovered run #{event.alert.name} on #{event.alert.host.name} after #{event[:duration] || "unknown"} sec"
  end

  defp get_message(event, :warn, :ok) do
    "start to fail #{event.alert.name} on #{event.alert.host.name}"
  end

  defp get_message(event, :warn, :warn) do
    "failing #{event.alert.name} on #{event.alert.host.name} lasting #{event.duration} sec"
  end

  defp get_message(event, :error, :warn) do
    "broken #{event.alert.name} on #{event.alert.host.name} lasting #{event[:duration] || "unknown"} sec"
  end

  defp get_message(event, :error, :error) do
    "still broken #{event.alert.name} on #{event.alert.host.name} lasting #{event.duration} sec"
  end
end
