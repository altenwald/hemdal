defmodule Hemdal.Config.Notifier do
  use Construct do
    field(:id, :string)
    field(:metadata, :map, default: %{})
    field(:token, :string)
    field(:type, :string, default: "Slack")
    field(:username, :string)
    field(:log_level, :string, default: "warn")
  end
end
