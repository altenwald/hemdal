defmodule Hemdal.Config.Host do
  @moduledoc """
  The host information.
  """

  use Construct do
    field(:id, :string)
    field(:name, :string)
    field(:type, :string, default: "Local")
    field(:options, :map, default: %{})
    field(:max_workers, :integer, default: 5)
  end
end
