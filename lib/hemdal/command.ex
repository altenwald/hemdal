defmodule Hemdal.Command do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.Alert

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}

  schema "commands" do
    field :command, :string
    field :name, :string
    field :command_type, :string

    has_many :alerts, Alert
    timestamps()
  end

  @doc false
  def changeset(command, attrs) do
    command
    |> cast(attrs, [:name, :command])
    |> validate_required([:name, :command])
  end
end
