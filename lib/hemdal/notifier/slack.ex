defmodule Hemdal.Notifier.Slack do
  use Tesla
  require Logger

  plug(Tesla.Middleware.BaseUrl, "https://hooks.slack.com")
  plug(Tesla.Middleware.JSON)

  def attach(title, color, fields, img_url \\ "") do
    %{"title" => title, "color" => color, "fields" => fields, "img_url" => img_url}
  end

  def field(title, value, short \\ true) do
    %{"title" => title, "value" => value, "short" => short}
  end

  def send(slack_msg, uri, _metadata) do
    Logger.debug("sending to #{uri}: #{inspect(slack_msg)}")

    case post(uri, slack_msg) do
      {:ok, resp} -> resp.body
      {:error, _} = error -> error
    end
  end
end
