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
    state = %{
      log_all_events: Application.get_env(:hemdal, :log_all_events, false),
    }
    {:consumer, state, subscribe_to: [@event_manager]}
  end

  @impl true
  def handle_events(events, _from, state) do
    List.foldl(events, {:noreply, [], state},
               fn event, {:noreply, [], state} -> process_event(event, state)
                  _event, result -> result
               end)
  end

  def process_event(%{status: status, prev_status: status},
                    %{log_all_events: false} = state) do
    {:noreply, [], state}
  end
  def process_event(%{alert: alert, fail_started: duration, status: status,
                      metadata: metadata, prev_status: prev}, state) do
    message = case {status, prev} do
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
    {:noreply, [], state}
  end
end
