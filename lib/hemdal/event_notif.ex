defmodule Hemdal.EventNotif do
  use GenStage
  require Logger

  alias Hemdal.AlertNotif
  alias Hemdal.Api.Slack

  @event_manager Hemdal.EventManager

  @default_channel "#alerts"
  @default_username "Hemdal"
  @default_icon ":rotating_light:"

  def start_link([]) do
    GenStage.start_link __MODULE__, [], name: __MODULE__
  end

  def stop do
    GenStage.stop __MODULE__
  end

  @impl GenStage
  def init([]) do
    {:consumer, %{}, subscribe_to: [@event_manager]}
  end

  @impl true
  def handle_events(events, _from, state) do
    List.foldl(events, {:noreply, [], state},
               fn event, {:noreply, [], state} -> process_event(event, state)
                  _event, result -> result
               end)
  end

  defp to_text(:ok), do: "OK"
  defp to_text(:warn), do: "WARN"
  defp to_text(:error), do: "FAIL"
  defp to_text(:disabled), do: "OFF"
  defp to_text(_), do: "UNKNOWN"

  defp to_color(:ok), do: "#009900"
  defp to_color(:warn), do: "#FFDA55"
  defp to_color(:error), do: "#990000"
  defp to_color(:disabled), do: "#888888"
  defp to_color(_), do: "#444444"

  def process_event(%{alert: alert, fail_started: duration, status: status,
                      metadata: metadata, prev_status: prev}, state) do
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
    Enum.each(alert.alert_notifs, fn %AlertNotif{notif: notif} = alert_notif ->
      if alert_notif.log_all_events or status != prev do
        username = iff(notif.username, @default_username)
        icon = iff(notif.metadata["icon"], @default_icon)
        desc = iff(metadata["description"], "<no description>")
        fields = [%{"title" => "Host Name",
                    "value" => alert.host.name,
                    "short" => true},
                  %{"title" => "Command Name",
                    "value" => alert.command.name,
                    "short" => true},
                  %{"title" => "Description",
                    "value" => desc,
                    "short" => false},
                  %{"title" => "Status",
                    "value" => to_text(status),
                    "short" => true},
                  %{"title" => "Prev. Status",
                    "value" => to_text(prev),
                    "short" => true},
                  %{"title" => "Duration",
                    "value" => "#{duration} sec",
                    "short" => true}]
        atts = [%{"title" => alert.name,
                  "fields" => fields,
                  "image_url" => "",
                  "color" => to_color(status)}]
        channel = iff(notif.metadata["channel"], @default_channel)
        message = %{"text" => message,
                    "username" => username,
                    "icon_emoji" => icon,
                    "channel" => channel,
                    "attachments" => atts}
        Slack.send(message, notif.token)
      end
    end)
    {:noreply, [], state}
  end

  defp iff(nil, default), do: default
  defp iff(element, _default), do: element
end
