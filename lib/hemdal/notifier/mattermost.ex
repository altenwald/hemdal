defmodule Hemdal.Notifier.Mattermost do
  use Tesla
  require Logger

  plug(Tesla.Middleware.JSON)

  def attach(title, color, fields, img_url \\ "") do
    %{"title" => title, "color" => color, "fields" => fields, "img_url" => img_url}
  end

  def field(title, value, short \\ true) do
    %{"title" => title, "value" => value, "short" => short}
  end

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
