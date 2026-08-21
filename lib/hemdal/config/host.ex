defmodule Hemdal.Config.Host do
  @moduledoc """
  The host information.
  """

  use Construct do
    field(:id, :string)
    field(:name, :string)
    field(:module, Hemdal.Config.Module, default: Hemdal.Host.Local)
    field(:options, Hemdal.Config.Options, default: [])
    field(:max_workers, Hemdal.Config.MaxWorkers, default: 5)
  end
end
