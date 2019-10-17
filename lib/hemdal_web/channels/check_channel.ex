defmodule Hemdal.CheckChannel do
  use Phoenix.Channel

  def join("checks:all", _params, socket) do
    {:ok, socket}
  end

  intercept ["event"]

  def handle_out("event", event, socket) do
    push(socket, "event", event)
    {:noreply, socket}
  end
end
