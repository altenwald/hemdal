defmodule Hemdal.Repo.Migrations.AddUsernameAndPasswordToHost do
  use Ecto.Migration

  def change do
    alter table(:hosts) do
      add :username, :string
      add :password, :string
    end
  end
end
