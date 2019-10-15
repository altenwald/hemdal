defmodule Hemdal.Log do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.{Log, Alert, Repo}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}

  schema "logs" do
    field :message, :string
    field :status, :string
    field :metadata, :map, default: %{}

    belongs_to :alert, Alert
    timestamps()
  end

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, [:message, :metadata, :alert_id, :status])
    |> validate_required([:message, :alert_id, :status])
  end

  def insert(alert, status, duration, message, metadata) do
    metadata = metadata
               |> Map.put("duration", duration)
               |> Enum.map(fn {key, value} -> {key, to_string(value)} end)
               |> Enum.into(%{})
    changeset(%Log{}, %{"metadata" => metadata,
                        "status" => Atom.to_string(status),
                        "message" => message,
                        "alert_id" => alert.id})
    |> Repo.insert()
  end
end
