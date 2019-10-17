defmodule Hemdal.Group do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.Alert

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}

  schema "groups" do
    field :name, :string

    has_many :alerts, Alert
    timestamps()
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
