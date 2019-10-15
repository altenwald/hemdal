defmodule Hemdal.Repo.Migrations.CreateAlerts do
  use Ecto.Migration

  def change do
    create table(:alerts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :command_id, references(:commands, type: :uuid, on_delete: :nothing)
      add :host_id, references(:hosts, type: :uuid, on_delete: :nothing)
      add :recheck_in_sec, :integer, default: 5
      add :retries, :integer, default: 3

      timestamps()
    end

    create index(:alerts, [:host_id])
    create index(:alerts, [:command_id])
  end
end
