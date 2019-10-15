defmodule Hemdal.Repo.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS hstore;"

    create table(:logs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :message, :text
      add :status, :string
      add :metadata, :hstore
      add :alert_id, references(:alerts, type: :uuid, on_delete: :nothing)

      timestamps()
    end

    create index(:logs, [:alert_id])
  end
end
