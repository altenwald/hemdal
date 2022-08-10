defmodule Hemdal.Config.Host do
  use Construct do
    field(:id, :string)
    field(:name, :string)
    field(:type, :string, default: "Trooper")
    field(:description, :string, default: nil)
    field(:port, :integer, default: 22)
    field(:max_workers, :integer, default: 5)

    field :credential, default: nil do
      field(:id, :string)
      field(:type, :string)
      field(:username, :string)
      field(:password, :string, default: nil)
      field(:cert_key, :string, default: nil)
      field(:cert_pub, :string, default: nil)
    end
  end
end
