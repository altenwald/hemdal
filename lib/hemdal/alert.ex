defmodule Hemdal.Alert do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.{Repo, Host, Command, Alert, Group}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}

  schema "alerts" do
    field :enabled, :boolean, default: true
    field :name, :string
    field :recheck_in_sec, :integer, default: 5
    field :retries, :integer, default: 3
    field :command_args, {:array, :string}, default: []

    belongs_to :host, Host
    belongs_to :command, Command
    belongs_to :group, Group
    timestamps()
  end

  @fields [:name, :command_id, :host_id, :group_id, :recheck_in_sec, :retries]
  @required_fields [:name, :command_id, :host_id, :group_id]

  @doc false
  def changeset(alert, attrs) do
    alert
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  def get_all do
    Repo.all(Alert)
    |> Repo.preload([:host, :command, :group])
  end

  def get_by_id!(id) do
    Alert
    |> Repo.get!(id)
    |> Repo.preload([:host, :command, :group])
  end
end
