defmodule Hemdal.Repo.Migrations.AddMaxWorkersToHosts do
  use Ecto.Migration

  def change do
    alter table(:hosts) do
      add :max_workers, :integer
    end

    execute "UPDATE hosts SET max_workers = 5"
  end
end
