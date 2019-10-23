defmodule Hemdal.Cred do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.Host

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}

  schema "creds" do
    field :type, :string
    field :username, :string
    field :password, :string
    field :cert_key, :string
    field :cert_pub, :string

    has_many :hosts, Host
    timestamps()
  end

  @required_fields [:type, :username]
  @optional_fields [:password, :cert_pub, :cert_key]

  @doc false
  def changeset(cred, attrs) do
    cred
    |> cast(attrs, @optional_fields ++ @required_fields)
    |> validate_required(@required_fields)
  end
end
