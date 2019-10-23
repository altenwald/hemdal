defmodule Hemdal.Host do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.{Repo, Alert, Host, Cred}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}

  schema "hosts" do
    field :name, :string
    field :description, :string
    field :port, :integer, default: 22
    field :max_workers, :integer, default: 5

    has_many :alerts, Alert
    belongs_to :cred, Cred
    timestamps()
  end

  @required_fields [:name]
  @optional_fields [:port, :description, :max_workers]

  @doc false
  def changeset(host, attrs) do
    host
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  def get_all do
    Repo.all(Host)
    |> Repo.preload([:cred])
  end

  def get_by_id!(id) do
    Repo.get!(Host, id)
    |> Repo.preload([:cred])
  end
end
