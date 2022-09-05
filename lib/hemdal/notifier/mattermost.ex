defmodule Hemdal.Notifier.Mattermost do
  @moduledoc """
  Performs the notification from `Hemdal.Notifier` using Mattermost. It's
  using the webhook capability of Slack to send the message to a specific
  channel. You can see further information in this link:

  https://developers.mattermost.com/integrate/webhooks/incoming/
  """
  use Hemdal.Notifier
  use Tesla
  require Logger
  alias Hemdal.Notifier

  plug(Tesla.Middleware.JSON)

  @impl Hemdal.Notifier
  @spec send(Notifier.message(), Notifier.token(), Notifier.metadata()) :: :ok | {:error, any()}
  @doc false
  def send(msg, token, metadata) do
    msg = %{
      "channel_id" => msg["channel"],
      "message" => msg["text"],
      "props" => %{"attachments" => msg["attachments"]}
    }

    headers = [
      {"authorization", "bearer #{token}"}
    ]

    metadata["base_url"]
    |> Path.join("/posts")
    |> tap(&Logger.debug("sending to #{inspect(&1)} (#{token}): #{inspect(msg)}"))
    |> post(msg, headers: headers)
    |> case do
      {:ok, _resp} ->
        :ok

      {:error, reason} = error ->
        Logger.error("sending: #{inspect(reason)}")
        error
    end
  end
end
