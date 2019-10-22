defmodule Hemdal.Host do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.{Repo, Alert, Host}

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
    field :max_workers, :integer, default: 5

    has_many :alerts, Alert
    timestamps()
  end

  @required_fields [:name, :access_type, :username]
  @optional_fields [:port, :access_key, :access_pub, :password, :description,
                    :max_workers]

  @doc false
  def changeset(host, attrs) do
    host
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  def get_all, do: Repo.all(Host)
  def get_by_id!(id), do: Repo.get!(Host, id)
end
