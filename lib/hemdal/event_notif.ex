defmodule Hemdal.EventNotif do
  use GenStage
  require Logger

  alias Hemdal.AlertNotif

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

  defp check_log_level("debug", _, _), do: true
  defp check_log_level("error", :error, status) when status != :error, do: true
  defp check_log_level("error", prev, :error) when prev != :error, do: true
  defp check_log_level("error", _prev, _status), do: false
  defp check_log_level("warn", prev, status), do: prev != status
  defp check_log_level(level, prev, status) do
    raise """
          \n*******
          ERROR! The value for level (#{inspect level}) isn't valid!
          Check it out in your configuration and set: "warn", "error" or
          "debug".

          Previous status: #{prev}
          New status: #{status}
          """
  end

  defp get_msg(alert, _duration, :disabled, _) do
    "disabled #{alert.name} on #{alert.host.name}"
  end
  defp get_msg(alert, _duration, :ok, :ok) do
    "sucessful run #{alert.name} on #{alert.host.name}"
  end
  defp get_msg(alert, duration, :ok, :warn) do
    "sucessful again run #{alert.name} on #{alert.host.name} " <>
    "after #{duration} sec"
  end
  defp get_msg(alert, duration, :ok, :error) do
    "recovered run #{alert.name} on #{alert.host.name} after #{duration} sec"
  end
  defp get_msg(alert, _duration, :warn, :ok) do
    "start to fail #{alert.name} on #{alert.host.name}"
  end
  defp get_msg(alert, duration, :warn, :warn) do
    "failing #{alert.name} on #{alert.host.name} lasting #{duration} sec"
  end
  defp get_msg(alert, duration, :error, :warn) do
    "broken #{alert.name} on #{alert.host.name} lasting #{duration} sec"
  end
  defp get_msg(alert, duration, :error, :error) do
    "still broken #{alert.name} on #{alert.host.name} lasting #{duration} sec"
  end

  def process_event(%{alert: alert, fail_started: duration, status: status,
                      metadata: metadata, prev_status: prev}, state) do
    Enum.each(alert.alert_notifs, fn %AlertNotif{notif: notif} = alert_notif ->
      if check_log_level(alert_notif.log_level, prev, status) do
        notif_mod = Module.concat([Hemdal.Api, notif.type])
        username = iff(notif.username, @default_username)
        icon = iff(notif.metadata["icon"], @default_icon)
        desc = iff(metadata["message"], "<no description>")
        fields = [notif_mod.field("Host Name", alert.host.name),
                  notif_mod.field("Command Name", alert.command.name),
                  notif_mod.field("Description", desc, false),
                  notif_mod.field("Status", to_text(status)),
                  notif_mod.field("Prev. Status", to_text(prev)),
                  notif_mod.field("Duration", "#{duration} sec"),
                  notif_mod.field("Incoming Status", metadata["status"])]
        atts = [notif_mod.attach(alert.name, to_color(status), fields)]
        channel = iff(notif.metadata["channel"], @default_channel)
        message = %{"text" => get_msg(alert, duration, status, prev),
                    "username" => username,
                    "icon_emoji" => icon,
                    "channel" => channel,
                    "attachments" => atts}
        notif_mod.send(message, notif.token)
      end
    end)
    {:noreply, [], state}
  end

  defp iff(nil, default), do: default
  defp iff(element, _default), do: element
end
