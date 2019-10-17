defmodule Hemdal.Repo.Migrations.CreateAlertNotifs do
  use Ecto.Migration

  def change do
    create table(:alert_notifs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :log_all_events, :boolean, default: false, null: false
      add :alert_id, references(:alerts, type: :uuid, on_delete: :nothing)
      add :notif_id, references(:notifs, type: :uuid, on_delete: :nothing)

      timestamps()
    end

    create index(:alert_notifs, [:alert_id])
    create index(:alert_notifs, [:notif_id])
  end
end
