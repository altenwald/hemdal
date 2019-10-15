defmodule Hemdal.Repo.Migrations.CreateCommands do
  use Ecto.Migration

  def change do
    create table(:commands, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :command, :text

      timestamps()
    end

  end
end
