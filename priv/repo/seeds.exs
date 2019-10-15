# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Hemdal.Repo.insert!(%Hemdal.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Hemdal.{Repo, Alert, Host, Command}

alert_id = "aea48656-be08-4576-a2d0-2723458faefd"
host_id = UUID.uuid4()
command_id = UUID.uuid4()

host = %Host{
  id: host_id,
  name: "127.0.0.1",
  port: 40400,
  access_type: "certificate",
  username: "manuel.rubio",
  password: nil,
  access_key: File.read!(Path.join([__DIR__, "../../test/user/id_rsa"])),
  access_pub: File.read!(Path.join([__DIR__, "../../test/user/id_rsa.pub"]))
}
command = %Command{
  id: command_id,
  name: "get ok status",
  command: """
           ["OK", "valid one!"].
           """
}
%Alert{} = %Alert{
  id: alert_id,
  name: "valid alert check",
  host_id: host_id,
  host: host,
  command_id: command_id,
  command: command,
  recheck_in_sec: 1,
  retries: 1
}
|> Alert.changeset(%{})
|> Repo.insert!()

alert_id = "6b6d247c-48c3-4a8c-9b4f-773f178ddc0f"
host_id = UUID.uuid4()
command_id = UUID.uuid4()

host = %Host{
  id: host_id,
  name: "127.0.0.1",
  port: 50500,
  access_type: "certificate",
  username: "manuel.rubio",
  password: nil,
  access_key: File.read!(Path.join([__DIR__, "../../test/user/id_rsa"])),
  access_pub: File.read!(Path.join([__DIR__, "../../test/user/id_rsa.pub"]))
}
command = %Command{
  id: command_id,
  name: "get failed status",
  command: """
           ["FAIL", "invalid one!"].
           """
}
%Alert{} = %Alert{
  id: alert_id,
  name: "invalid alert check",
  host_id: host_id,
  host: host,
  command_id: command_id,
  command: command,
  recheck_in_sec: 1,
  retries: 1
}
|> Alert.changeset(%{})
|> Repo.insert!()
