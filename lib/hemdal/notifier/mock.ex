defmodule Hemdal.Notifier.Mock do
  @moduledoc """
  Let us perform tests using a notifier which we can control. It's working
  injecting inside of the metadata the PID of the process where the
  notification should be triggered.

  Inside of the configuration we have to inject the notifier with the
  corresponding information, it's important to choose a backend which let us
  use the PID as data. If you see `Hemdal.CheckTest` you can find a way
  about how to do this.
  """
  use Hemdal.Notifier
  require Logger
  alias Hemdal.Notifier

  @impl Hemdal.Notifier
  @spec send(Notifier.message(), Notifier.token(), Notifier.metadata()) :: :ok
  @doc false
  def send(msg, "TOKEN", metadata) do
    Logger.debug("mock notify #{inspect(msg)}")
    send(metadata.pid, {:notifier, msg, metadata})
    :ok
  end
end
