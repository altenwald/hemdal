defmodule Hemdal.Repo.Migrations.CreateNotifs do
  use Ecto.Migration

  def change do
    create table(:notifs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :token, :string
      add :username, :string
      add :type, :string
      add :metadata, :hstore

      timestamps()
    end

  end
end
