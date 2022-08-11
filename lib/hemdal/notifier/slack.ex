defmodule Hemdal.Notifier.Slack do
  use Hemdal.Notifier
  use Tesla
  require Logger

  plug(Tesla.Middleware.BaseUrl, "https://hooks.slack.com")
  plug(Tesla.Middleware.JSON)

  @impl Hemdal.Notifier
  def send(slack_msg, uri, _metadata) do
    Logger.debug("sending to #{uri}: #{inspect(slack_msg)}")

    case post(uri, slack_msg) do
      {:ok, resp} -> resp.body
      {:error, _} = error -> error
    end
  end
end
