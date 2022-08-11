defmodule Hemdal.Notifier.Mattermost do
  use Hemdal.Notifier
  use Tesla
  require Logger

  plug(Tesla.Middleware.JSON)

  @impl Hemdal.Notifier
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
      {:ok, resp} ->
        resp.body

      {:error, _} = error ->
        Logger.error("sending: #{inspect(error)}")
        error
    end
  end
end
