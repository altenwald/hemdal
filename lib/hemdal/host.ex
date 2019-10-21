defmodule Hemdal.Host do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.Alert

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}

  schema "hosts" do
    field :name, :string
    field :description, :string
    field :port, :integer, default: 22
    field :access_type, :string
    field :username, :string
    field :password, :string
    field :access_key, :string
    field :access_pub, :string

    has_many :alerts, Alert
    timestamps()
  end

  @required_fields [:name, :access_type, :username]
  @optional_fields [:port, :access_key, :access_pub, :password, :description]

  @doc false
  def changeset(host, attrs) do
    host
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
