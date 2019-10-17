defmodule Hemdal.Api.Slack do
  use Tesla
  require Logger

  plug Tesla.Middleware.BaseUrl, "https://hooks.slack.com"
  plug Tesla.Middleware.JSON

  def attach(title, color \\ "#b0364d", text) do
    %{"title" => title, "color" => color, "text" => text}
  end

  def field(title, color \\ "#b0364d", value, short \\ true) do
    %{"title" => title, "color" => color, "value" => value, "short" => short}
  end

  def send(slack_msg, uri) do
    Logger.debug "sending to #{uri}: #{inspect slack_msg}"
    case post(uri, slack_msg) do
      {:ok, resp} -> resp.body
      {:error, _} = error -> error
    end
  end
end
