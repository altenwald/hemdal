defmodule Hemdal.Event.Mock do
  use GenStage

  @event_manager Hemdal.Event

  def start_link do
    GenStage.start_link(__MODULE__, [self()])
  end

  defdelegate stop(pid), to: GenStage

  @impl GenStage
  def init([pid]) do
    {:consumer, pid, subscribe_to: [@event_manager]}
  end

  @impl true
  def handle_events(events, from, pid) do
    Enum.each(events, &send(pid, {:event, from, &1}))
    {:noreply, [], pid}
  end
end
