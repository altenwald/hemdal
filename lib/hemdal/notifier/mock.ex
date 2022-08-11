defmodule Hemdal.Notifier.Mock do
  use Hemdal.Notifier
  require Logger

  @impl Hemdal.Notifier
  def send(msg, "TOKEN", metadata) do
    Logger.debug("mock notify #{inspect(msg)}")
    send(metadata.pid, {:notifier, msg, metadata})
    :ok
  end
end
