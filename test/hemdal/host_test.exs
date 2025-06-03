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

  test "start all & stop all" do
    assert [] == Hemdal.Host.get_all()
    assert :ok == Hemdal.Host.start_all()
    refute [] == Hemdal.Host.get_all()
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

  test "run shell command" do
    assert :ok = Hemdal.Host.reload_all()
    assert [host_id, _] = Hemdal.Host.get_all()

    echo = %Hemdal.Config.Command{
      name: "hello world!",
      type: "line",
      command: ~s|echo '{"status": "OK", "message": "hello world!"}'|
    }

    assert {:ok, %{"message" => "hello world!"}} = Hemdal.Host.exec(host_id, echo)
  end

  test "run background shell command" do
    assert :ok = Hemdal.Host.reload_all()
    assert [host_id, _] = Hemdal.Host.get_all()

    echo = %Hemdal.Config.Command{
      name: "hello world!",
      type: "line",
      command: ~s|echo '{"status": "OK", "message": "hello world!"}'|
    }

    assert {:ok, worker} = Hemdal.Host.exec_background(host_id, echo)
    assert is_pid(worker)
    assert_receive {:ok, %{"message" => "hello world!"}}, 5_000
  end

  test "run script" do
    assert :ok = Hemdal.Host.reload_all()
    assert [host_id, _] = Hemdal.Host.get_all()

    echo = %Hemdal.Config.Command{
      name: "hello world!",
      type: "script",
      command: """
      #!/bin/bash

      MESSAGE="Hello World!"
      STATUS="OK"

      echo '{"status": "'$STATUS'", "message": "'$MESSAGE'"}'
      """
    }

    assert {:ok, %{"message" => "Hello World!"}} = Hemdal.Host.exec(host_id, echo)
  end

  test "run background script" do
    assert :ok = Hemdal.Host.reload_all()
    assert [host_id, _] = Hemdal.Host.get_all()

    echo = %Hemdal.Config.Command{
      name: "hello world!",
      type: "script",
      command: """
      #!/bin/bash

      MESSAGE="Hello World!"
      STATUS="OK"

      echo '{"status": "'$STATUS'", "message": "'$MESSAGE'"}'
      """
    }

    assert {:ok, _worker} = Hemdal.Host.exec_background(host_id, echo)
    assert_receive {:ok, %{"message" => "Hello World!"}}, 5_000
  end

  test "run interactive shell command" do
    assert :ok = Hemdal.Host.reload_all()
    assert [host_id, _] = Hemdal.Host.get_all()

    echo = %Hemdal.Config.Command{
      name: "hello world!",
      type: "line",
      interactive: true,
      command: "cat"
    }

    pid =
      spawn_link(fn ->
        assert_receive {:start, pid}
        send(pid, {:data, ~s|{"status": "OK",\n|})
        assert_receive {:continue, ~s|{"status": "OK",\n|}
        send(pid, {:data, ~s| "message": "hello world!"}\n|})
        assert_receive {:continue, ~s| "message": "hello world!"}\n|}
        send(pid, :close)
        assert_receive :closed
      end)

    assert {:ok, %{"message" => "hello world!"}} = Hemdal.Host.exec(host_id, echo, caller: pid)
  end

  test "error running interactive shell command" do
    assert :ok = Hemdal.Host.reload_all()
    assert [host_id, _] = Hemdal.Host.get_all()

    echo = %Hemdal.Config.Command{
      name: "hello world!",
      type: "line",
      interactive: true,
      command: "cat"
    }

    assert {:error, %{"message" => "Impossible combination"}} = Hemdal.Host.exec(host_id, echo)
  end

  test "run interactive background shell command" do
    assert :ok = Hemdal.Host.reload_all()
    assert [host_id, _] = Hemdal.Host.get_all()

    echo = %Hemdal.Config.Command{
      name: "hello world!",
      type: "line",
      interactive: true,
      command: "cat"
    }

    assert {:ok, runner} = Hemdal.Host.exec_background(host_id, echo)
    assert is_pid(runner)

    assert_receive {:start, worker}
    assert is_pid(worker)
    refute runner != worker

    send(worker, {:data, ~s|{"status": "OK",\n|})
    assert_receive {:continue, ~s|{"status": "OK",\n|}
    send(worker, {:data, ~s| "message": "hello world!"}\n|})
    assert_receive {:continue, ~s| "message": "hello world!"}\n|}
    send(worker, :close)
    assert_receive :closed

    assert_receive {:ok, %{"message" => "hello world!"}}, 5_000
  end

  test "run shell" do
    assert :ok = Hemdal.Host.reload_all()
    assert [host_id, _] = Hemdal.Host.get_all()

    echo = %Hemdal.Config.Command{
      name: "hello world!",
      type: "shell",
      interactive: true,
      command: "cat"
    }

    assert {:ok, runner} = Hemdal.Host.exec_background(host_id, echo)
    assert is_pid(runner)

    assert_receive {:start, worker}
    assert is_pid(worker)
    refute runner != worker

    send(worker, {:data, ~s|{"status": "OK",\n|})
    assert_receive {:continue, ~s|{"status": "OK",\n|}
    send(worker, {:data, ~s| "message": "hello world!"}\n|})
    assert_receive {:continue, ~s| "message": "hello world!"}\n|}
    send(worker, {:data, <<4>>})
    assert_receive {:continue, "\x04"}
    assert_receive {:continue, ~s|{"status": "OK",\n "message": "hello world!"}\n\x04|}
    send(worker, :close)
    assert_receive :closed

    message = ~s|{"status": "OK",\n "message": "hello world!"}\n\x04|
    received_message = message <> message
    assert_receive {:error, %{"message" => ^received_message}}, 5_000
  end
end
