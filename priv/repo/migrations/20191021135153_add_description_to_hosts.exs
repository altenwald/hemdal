defmodule Hemdal.Repo.Migrations.AddDescriptionToHosts do
  use Ecto.Migration

  def change do
    alter table(:hosts) do
      add :description, :string
    end

    execute "UPDATE hosts SET description = name"
  end
end
