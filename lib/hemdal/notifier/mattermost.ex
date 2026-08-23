defmodule Hemdal.Notifier.Mattermost do
  @moduledoc """
  Performs the notification from `Hemdal.Notifier` using Mattermost. It's
  using the webhook capability of Slack to send the message to a specific
  channel. You can see further information in this link:

  https://developers.mattermost.com/integrate/webhooks/incoming/
  """
  use Hemdal.Notifier
  require Logger
  alias Hemdal.Notifier

  @impl Hemdal.Notifier
  @spec send(Notifier.message(), Notifier.token(), Notifier.metadata()) :: :ok | {:error, any()}
  @doc false
  def send(msg, token, metadata) do
    msg = %{
      "channel_id" => msg["channel"],
      "message" => msg["text"],
      "props" => %{"attachments" => msg["attachments"]}
    }

    base_url =
      case metadata do
        %{"base_url" => url} -> url
        %{base_url: url} -> url
        _ -> "http://localhost"
      end
      |> String.trim_trailing("/")

    url = "#{base_url}/posts"

    Logger.debug("sending to #{inspect(url)} (#{token}): #{inspect(msg)}")

    headers = [
      {"authorization", "bearer #{token}"}
    ]

    case Req.post(url, json: msg, headers: headers) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("sending: status #{status}, body: #{inspect(body)}")
        {:error, %{status: status, body: body}}

      {:error, reason} = error ->
        Logger.error("sending: #{inspect(reason)}")
        error
    end
  end
end
