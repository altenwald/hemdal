defmodule Hemdal.Event do
  @moduledoc """
  Generate events to be consumed. It's the producer for the events.
  """
  use GenStage

  @doc false
  @spec start_link([]) :: {:ok, pid()}
  def start_link([]) do
    {:ok, _pid} = GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  @typedoc """
  The event is generated usually in `Hemdal.Check` module and it's
  based on the structure:

  - `alert` based on `Hemdal.Config.Alert`
  - `status` which is the current status to notify
  - `prev_status` which is the previous status
  - `fail_started` when the fail started to happens
  - `fail_duration` how long the fail is/was
  - `last_update` when the event was created
  - `metadata` more information for the event
  """
  @type t() :: %__MODULE__{
          alert: Hemdal.Config.Alert.t() | nil,
          status: Hemdal.Check.status(),
          prev_status: Hemdal.Check.status(),
          fail_started: NaiveDateTime.t() | nil,
          fail_duration: non_neg_integer(),
          last_update: NaiveDateTime.t(),
          metadata: map()
        }

  defstruct alert: nil,
            status: nil,
            prev_status: nil,
            fail_started: nil,
            fail_duration: 0,
            last_update: nil,
            metadata: %{}

  @spec notify(t()) :: :ok
  def notify(event), do: GenStage.cast(__MODULE__, {:notify, event})

  @impl GenStage
  @doc false
  def init([]) do
    {:producer, [], dispatcher: GenStage.BroadcastDispatcher}
  end

  @impl GenStage
  @doc false
  def handle_cast({:notify, event}, events) do
    {:noreply, [event], events}
  end

  @impl GenStage
  @doc false
  def handle_demand(demand, events) do
    {to_dispatch, to_keep} = Enum.split(events, demand)
    {:noreply, to_dispatch, to_keep}
  end
end
