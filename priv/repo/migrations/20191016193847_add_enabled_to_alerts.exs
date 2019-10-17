defmodule Hemdal.Repo.Migrations.AddEnabledToAlerts do
  use Ecto.Migration

  def change do
    alter table(:alerts) do
      add :enabled, :boolean
    end

    execute "UPDATE alerts SET enabled = true"
  end
end
