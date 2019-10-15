defmodule Hemdal.Alert do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.{Host, Command, Alert, Repo}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}

  schema "alerts" do
    field :name, :string
    field :recheck_in_sec, :integer, default: 5
    field :retries, :integer, default: 3

    belongs_to :host, Host
    belongs_to :command, Command
    timestamps()
  end

  @doc false
  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [:name, :command_id, :host_id, :recheck_in_sec, :retries])
    |> validate_required([:name, :command_id, :host_id])
  end

  def get_all do
    Repo.all(Alert)
    |> Repo.preload([:host, :command])
  end
end