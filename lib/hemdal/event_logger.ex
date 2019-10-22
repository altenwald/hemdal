defmodule Hemdal.EventLogger do
  use GenStage
  require Logger

  @event_manager Hemdal.EventManager

  def start_link([]) do
    GenStage.start_link __MODULE__, [], name: __MODULE__
  end

  def stop do
    GenStage.stop __MODULE__
  end

  @impl GenStage
  def init([]) do
    state = %{log_level: Application.get_env(:hemdal, :log_level, "warn")}
    {:consumer, state, subscribe_to: [@event_manager]}
  end

  @impl true
  def handle_events(events, _from, state) do
    Enum.each(events, &(process_event(&1, state.log_level)))
    {:noreply, [], state}
  end

  def process_event(%{status: status, prev_status: prev}, "error")
    when not(status == "FAIL" and prev != "FAIL") and
         not(status != "FAIL" and prev == "FAIL") do
    :ok
  end
  def process_event(%{status: status, prev_status: status}, "warn"), do: :ok
  def process_event(%{alert: alert, fail_started: duration, status: status,
                      metadata: metadata, prev_status: prev}, _log_level) do
    message = case {status, prev} do
      {:disabled, _} -> "disabled #{alert.name} on #{alert.host.name}"
      {:ok, :ok} -> "sucessful run #{alert.name} on #{alert.host.name}"
      {:ok, :warn} -> "sucessful again run #{alert.name} on #{alert.host.name} after #{duration} sec"
      {:ok, :error} -> "recovered run #{alert.name} on #{alert.host.name} after #{duration} sec"
      {:warn, :ok} -> "start to fail #{alert.name} on #{alert.host.name}"
      {:warn, :warn} -> "failing #{alert.name} on #{alert.host.name} lasting #{duration} sec"
      {:error, :warn} -> "broken #{alert.name} on #{alert.host.name} lasting #{duration} sec"
      {:error, :error} -> "still broken #{alert.name} on #{alert.host.name} lasting #{duration} sec"
    end
    case status do
      :ok -> Logger.info message
      :warn -> Logger.warn message
      :error -> Logger.error message
    end
    Hemdal.Log.insert alert, status, duration, message, metadata
    :ok
  end
end
