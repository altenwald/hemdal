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

alias Hemdal.{Repo, Command}

[
  %Command{
    id: UUID.uuid4(),
    name: "check apt",
    command_type: "script",
    command: File.read!(Path.join([__DIR__, "scripts/check_apt"]))
  },
  %Command{
    id: UUID.uuid4(),
    name: "check erlang node",
    command_type: "script",
    command: File.read!(Path.join([__DIR__, "scripts/check_erlang_node"]))
  },
  %Command{
    id: UUID.uuid4(),
    name: "check ssl cert",
    command_type: "script",
    command: File.read!(Path.join([__DIR__, "scripts/check_ssl_cert"]))
  },
]
|> Enum.each(&(Repo.insert!(&1)))
