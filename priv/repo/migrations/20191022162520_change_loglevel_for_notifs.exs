defmodule Hemdal.Repo.Migrations.ChangeLoglevelForNotifs do
  use Ecto.Migration

  def change do
    alter table(:alert_notifs) do
      remove :log_all_events
      add :log_level, :string
    end

    execute "UPDATE alert_notifs SET log_level = 'error'"
  end
end
