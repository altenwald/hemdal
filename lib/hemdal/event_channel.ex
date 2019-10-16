defmodule Hemdal.EventChannel do
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
    state = %{}
    {:consumer, state, subscribe_to: [@event_manager]}
  end

  @impl true
  def handle_events(events, _from, state) do
    List.foldl(events, {:noreply, [], state},
               fn event, {:noreply, [], state} -> process_event(event, state)
                  _event, result -> result
               end)
  end

  defp build_reply(type, alert, last_update, status) do
    %{
      "status" => type,
      "alert" => %{
        "id" => alert.id,
        "name" => alert.name,
        "host" => alert.host.name,
        "command" => alert.command.name
      },
      "last_update" => Timex.format!(last_update, "%F %R", :strftime),
      "result" => status
    }
  end

  def process_event(%{alert: alert,
                      last_update: last_update,
                      status: status,
                      metadata: metadata}, state) do
    event = build_reply(status, alert, last_update, metadata)
    Logger.info "sending event to channel: #{inspect event}"
    HemdalWeb.Endpoint.broadcast!("checks:all", "event", event)
    {:noreply, [], state}
  end
end
