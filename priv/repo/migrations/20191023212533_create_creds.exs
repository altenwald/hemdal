defmodule Hemdal.Repo.Migrations.CreateCreds do
  use Ecto.Migration

  def change do
    create table(:creds, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :type, :string
      add :username, :string
      add :password, :string
      add :cert_pub, :text
      add :cert_key, :text

      timestamps()
    end

    execute """
    INSERT INTO creds(id, type, username, password, cert_pub, cert_key,
                      inserted_at, updated_at)
    SELECT gen_random_uuid() AS id,
           access_type AS type,
           username,
           password,
           access_pub AS cert_pub,
           access_key AS cert_key,
           NOW() AS inserted_at,
           NOW() AS updated_at
    FROM hosts
    GROUP BY access_type, username, password, access_pub, access_key;
    """

    alter table(:hosts) do
      add :cred_id, references(:creds, type: :uuid, on_delete: :nothing)
    end
    create index(:hosts, [:cred_id])

    execute """
    UPDATE hosts h
    SET cred_id = (SELECT id
                   FROM creds c
                   WHERE h.access_type = c.type
                     AND h.username = c.username
                     AND h.password = c.password
                     AND h.access_pub = c.cert_pub
                     AND h.access_key = c.cert_key)
    """

    alter table(:hosts) do
      remove :access_type
      remove :username
      remove :password
      remove :access_pub
      remove :access_key
    end
  end
end
