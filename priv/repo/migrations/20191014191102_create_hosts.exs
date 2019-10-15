defmodule Hemdal.Repo.Migrations.CreateHosts do
  use Ecto.Migration

  def change do
    create table(:hosts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :access_type, :string
      add :access_key, :text
      add :access_pub, :text

      timestamps()
    end

  end
end
