defmodule Hemdal.Config.Alert do
  alias Hemdal.Config.{Host, Notifier}

  use Construct do
    field(:id, :string)
    field(:enabled, :boolean, default: true)
    field(:name, :string)
    field(:check_in_sec, :integer, default: 60)
    field(:recheck_in_sec, :integer, default: 5)
    field(:broken_recheck_in_sec, :integer, default: 30)
    field(:retries, :integer, default: 3)
    field(:command_args, {:array, :string}, default: [])

    field(:host, Host)

    field :command do
      field(:id, :string)
      field(:command, :string)
      field(:name, :string)
      field(:command_type, :string)
    end

    field :group, default: nil do
      field(:id, :string)
      field(:name, :string)
    end

    field(:notifiers, {:array, Notifier}, default: [])
  end
end
