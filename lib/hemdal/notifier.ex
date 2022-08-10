defmodule Hemdal.Notifier do
  @default_channel "#alerts"
  @default_username "Hemdal"
  @default_icon ":rotating_light:"
  @default_desc "<no description>"

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

  def send(notifier, status, prev, alert, metadata, duration) do
    notifier_mod = Module.concat([__MODULE__, notifier.type])
    desc = metadata["message"] || @default_desc
    channel = notifier.metadata["channel"] || @default_channel
    username = notifier.username || @default_username
    icon = notifier.metadata["icon"] || @default_icon

    fields = [
      notifier_mod.field("Host Name", alert.host.name),
      notifier_mod.field("Command Name", alert.command.name),
      notifier_mod.field("Description", desc, false),
      notifier_mod.field("Status", to_text(status)),
      notifier_mod.field("Prev. Status", to_text(prev)),
      notifier_mod.field("Duration", "#{duration} sec"),
      notifier_mod.field("Incoming Status", metadata["status"])
    ]

    atts = [notifier_mod.attach(alert.name, to_color(status), fields)]

    message = %{
      "text" => get_msg(alert, duration, status, prev),
      "username" => username,
      "icon_emoji" => icon,
      "channel" => channel,
      "attachments" => atts
    }

    notifier_mod.send(message, notifier.token, notifier.metadata)
  end
end
