defmodule Hemdal.Host do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.Alert

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}

  schema "hosts" do
    field :name, :string
    field :access_type, :string
    field :username, :string
    field :password, :string
    field :access_key, :string
    field :access_pub, :string

    has_many :alerts, Alert
    timestamps()
  end

  @doc false
  def changeset(host, attrs) do
    host
    |> cast(attrs, [:name, :access_type, :access_key, :access_pub])
    |> validate_required([:name, :access_type, :access_key, :access_pub])
  end
end
