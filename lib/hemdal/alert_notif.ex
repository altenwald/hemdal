defmodule Hemdal.AlertNotif do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hemdal.{Alert, Notif}

  @log_level_msg "log_level must to be error, warn or debug"

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}

  schema "alert_notifs" do
    field :log_level, :string, default: "warn"

    belongs_to :alert, Alert
    belongs_to :notif, Notif

    timestamps()
  end

  @required_fields [:alert_id, :notif_id]
  @optional_fields [:log_level]

  @doc false
  def changeset(alert_notif, attrs) do
    alert_notif
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:alert_id)
    |> foreign_key_constraint(:notif_id)
    |> validate_log_level()
  end

  defp validate_log_level(changeset) do
    case get_field(changeset, :log_level, "warn") do
      "debug" -> changeset
      "warn" -> changeset
      "error" -> changeset
      value -> add_error(changeset, :log_level, @log_level_msg)
    end
  end
end
