defmodule Hemdal.Repo.Migrations.AddGroupIdToAlerts do
  use Ecto.Migration

  def change do
    alter table(:alerts) do
      add :group_id, references(:groups, type: :uuid, on_delete: :nothing)
    end
  end
end
