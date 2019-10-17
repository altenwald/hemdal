defmodule Hemdal.AlertNotif do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.{Alert, Notif}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}

  schema "alert_notifs" do
    field :log_all_events, :boolean, default: false

    belongs_to :alert, Alert
    belongs_to :notif, Notif

    timestamps()
  end

  @doc false
  def changeset(alert_notif, attrs) do
    alert_notif
    |> cast(attrs, [:log_all_events, :alert_id, :notif_id])
    |> validate_required([:log_all_events, :alert_id, :notif_id])
    |> foreign_key_constraint(:alert_id)
    |> foreign_key_constraint(:notif_id)
  end
end
