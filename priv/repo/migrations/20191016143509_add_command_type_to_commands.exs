defmodule Hemdal.Repo.Migrations.AddCommandTypeToCommands do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      add :command_type, :string
    end

    execute "UPDATE commands SET command_type = 'line'"
  end
end
