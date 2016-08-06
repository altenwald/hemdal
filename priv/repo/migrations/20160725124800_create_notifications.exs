defmodule Heimdall.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
        add :hostname, :string
        add :groupkey, :string
        add :name, :string
        add :description, :string
        add :status_text, :string
        add :status, :integer

        timestamps
    end
  end
end
