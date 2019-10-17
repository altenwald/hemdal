defmodule Hemdal.Repo.Migrations.AddCommandArgsToAlerts do
  use Ecto.Migration

  def change do
    alter table(:alerts) do
      add :command_args, {:array, :string}
    end

    execute "UPDATE alerts SET command_args = '{}'::varchar[]"
  end
end
