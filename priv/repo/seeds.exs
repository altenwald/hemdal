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
  %Command{
    id: UUID.uuid4(),
    name: "check docker",
    command_type: "script",
    command: File.read!(Path.join([__DIR__, "scripts/check_docker"]))
  },
  %Command{
    id: UUID.uuid4(),
    name: "check docker memory",
    command_type: "script",
    command: File.read!(Path.join([__DIR__, "scripts/check_docker_mem"]))
  },
  %Command{
    id: UUID.uuid4(),
    name: "check daemon",
    command_type: "script",
    command: File.read!(Path.join([__DIR__, "scripts/check_daemon"]))
  },
  %Command{
    id: UUID.uuid4(),
    name: "check php fpm",
    command_type: "script",
    command: File.read!(Path.join([__DIR__, "scripts/check_php_fpm"]))
  },
]
|> Enum.each(&(Repo.insert!(&1)))
