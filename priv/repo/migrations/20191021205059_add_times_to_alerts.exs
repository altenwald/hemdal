defmodule Hemdal.Repo.Migrations.AddTimesToAlerts do
  use Ecto.Migration

  def change do
    alter table(:alerts) do
      add :check_in_sec, :integer
      add :broken_recheck_in_sec, :integer
    end

    execute "UPDATE alerts SET check_in_sec = 60, broken_recheck_in_sec = 10"
  end
end
