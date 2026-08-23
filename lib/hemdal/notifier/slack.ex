defmodule Hemdal.Notifier.Slack do
  @moduledoc """
  Performs the notification from `Hemdal.Notifier` using Slack. It's using the
  webhook capability of Slack to send the message to a specific channel. You
  can see further information in this link:

  https://api.slack.com/messaging/webhooks
  """
  use Hemdal.Notifier
  require Logger
  alias Hemdal.Notifier

  @base_url "https://hooks.slack.com"

  @impl Hemdal.Notifier
  @doc false
  @spec send(Notifier.message(), Notifier.token(), Notifier.metadata()) :: :ok | {:error, any()}
  def send(slack_msg, uri, _metadata) do
    Logger.debug("sending to #{uri}: #{inspect(slack_msg)}")

    case Req.post(uri, base_url: @base_url, json: slack_msg) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("cannot send message for Slack: status #{status}, body: #{inspect(body)}")
        {:error, %{status: status, body: body}}

      {:error, reason} = error ->
        Logger.error("cannot send message for Slack: #{inspect(reason)}")
        error
    end
  end
end
