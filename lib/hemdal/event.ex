defmodule Hemdal.Event do
  use GenStage

  def start_link([]) do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def notify(event), do: GenStage.cast(__MODULE__, {:notify, event})

  def init([]) do
    {:producer, [], dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_cast({:notify, event}, events) do
    {:noreply, [event], events}
  end

  def handle_demand(demand, events) do
    {to_dispatch, to_keep} = Enum.split(events, demand)
    {:noreply, to_dispatch, to_keep}
  end
end
