defmodule Hemdal.Repo.Migrations.AddPortToHosts do
  use Ecto.Migration

  def change do
    alter table(:hosts) do
      add :port, :integer
    end

    execute "UPDATE hosts SET port = 22"
  end
end
