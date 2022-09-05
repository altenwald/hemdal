defmodule Hemdal.Notifier.Slack do
  @moduledoc """
  Performs the notification from `Hemdal.Notifier` using Slack. It's using the
  webhook capability of Slack to send the message to a specific channel. You
  can see further information in this link:

  https://api.slack.com/messaging/webhooks
  """
  use Hemdal.Notifier
  use Tesla
  require Logger
  alias Hemdal.Notifier

  @typedoc """
  Because of an error in Construct, we need to provide the type
  `t()` for each default value if that's a module or an atom different
  from `nil`, `true`, `false`:

  https://github.com/ExpressApp/construct/issues/38

  Remove this type when the issue is closed and the code is in use by
  this library.
  """
  @type t() :: module()

  plug(Tesla.Middleware.BaseUrl, "https://hooks.slack.com")
  plug(Tesla.Middleware.JSON)

  @impl Hemdal.Notifier
  @doc false
  @spec send(Notifier.message(), Notifier.token(), Notifier.metadata()) :: :ok | {:error, any()}
  def send(slack_msg, uri, _metadata) do
    Logger.debug("sending to #{uri}: #{inspect(slack_msg)}")

    case post(uri, slack_msg) do
      {:ok, _resp} ->
        :ok

      {:error, reason} = error ->
        Logger.error("cannot send message for Slack: #{inspect(reason)}")
        error
    end
  end
end
