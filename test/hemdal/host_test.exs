defmodule Hemdal.HostTest do
  use ExUnit.Case, async: false

  def host(id) do
    [
      id: Enum.random(1..1000),
      name: "empty alert check",
      host: [
        id: id,
        module: Hemdal.Host.Local,
        name: "localhost",
        max_workers: 1
      ]
    ]
  end

  setup do
    Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Env)

    Application.put_env(:hemdal, Hemdal.Config, [
      host("f8441510-95db-4e00-a3e0-1556bb8a778c"),
      host("78eb75f9-2ac7-434c-a1a2-330b23c89982")
    ])

    Enum.each(Hemdal.Host.get_all(), &Hemdal.Host.stop/1)
  end

  test "start & stop host" do
    host = Hemdal.Config.get_host_by_id!("f8441510-95db-4e00-a3e0-1556bb8a778c")

    assert %Hemdal.Config.Host{
             id: "f8441510-95db-4e00-a3e0-1556bb8a778c",
             module: Hemdal.Host.Local
           } = host

    assert :ok = Hemdal.Host.start(host)
    assert Hemdal.Host.exists?(host.id)

    assert :ok = Hemdal.Host.stop(host.id)
    refute Hemdal.Host.exists?(host.id)
  end

  test "get all hosts" do
    host = Hemdal.Config.get_host_by_id!("78eb75f9-2ac7-434c-a1a2-330b23c89982")

    assert :ok = Hemdal.Host.start(host)
    assert Hemdal.Host.exists?(host.id)

    assert host.id in Hemdal.Host.get_all()

    assert :ok = Hemdal.Host.stop(host.id)
    refute Hemdal.Host.exists?(host.id)

    refute host.id in Hemdal.Host.get_all()
  end

  test "add one reloading all hosts" do
    assert :ok = Hemdal.Host.reload_all()

    assert ~w[
      78eb75f9-2ac7-434c-a1a2-330b23c89982
      f8441510-95db-4e00-a3e0-1556bb8a778c
    ] == Hemdal.Host.get_all()

    Application.put_env(:hemdal, Hemdal.Config, [
      host("f8441510-95db-4e00-a3e0-1556bb8a778c"),
      host("78eb75f9-2ac7-434c-a1a2-330b23c89982"),
      host("92412973-4d6c-4c08-86ed-82d64f8ea756")
    ])

    assert :ok = Hemdal.Host.reload_all()

    assert ~w[
      78eb75f9-2ac7-434c-a1a2-330b23c89982
      92412973-4d6c-4c08-86ed-82d64f8ea756
      f8441510-95db-4e00-a3e0-1556bb8a778c
    ] == Hemdal.Host.get_all()
  end

  test "remove one reloading all hosts" do
    assert :ok = Hemdal.Host.reload_all()

    assert ~w[
      78eb75f9-2ac7-434c-a1a2-330b23c89982
      f8441510-95db-4e00-a3e0-1556bb8a778c
    ] == Hemdal.Host.get_all()

    Application.put_env(:hemdal, Hemdal.Config, [
      host("78eb75f9-2ac7-434c-a1a2-330b23c89982")
    ])

    assert :ok = Hemdal.Host.reload_all()

    assert ~w[
      78eb75f9-2ac7-434c-a1a2-330b23c89982
    ] == Hemdal.Host.get_all()
  end
end
