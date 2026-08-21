defmodule Hemdal.HostTest do
  use ExUnit.Case, async: false

  alias Hemdal.Host.Local

  def host(id) do
    [
      id: Enum.random(1..1000),
      name: "empty alert check",
      host: [
        id: id,
        module: Local,
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

    assert {:ok, _pid} = Hemdal.Host.start(host)
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

    assert {:ok, _pid} = Hemdal.Host.start(host)
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

  test "queue empty" do
    assert :ok = Hemdal.Host.reload_all()
    assert [host_id, _] = Hemdal.Host.get_all()

    long_run = %Hemdal.Config.Command{
      name: "wait",
      type: "line",
      command: "sleep 1 && printf DONE",
      output: false,
      decode: false
    }

    stats = Hemdal.Host.get_stats(host_id)
    assert 1 == stats.max_running_workers
    assert 0 == stats.running_workers
    assert 0 == stats.waiting_workers

    assert {:ok, _worker} = Hemdal.Host.exec_background(host_id, long_run)

    stats = Hemdal.Host.get_stats(host_id)
    assert 1 == stats.running_workers
    assert 0 == stats.waiting_workers

    spawn_monitor(fn ->
      assert {:ok, _worker} = Hemdal.Host.exec_background(host_id, long_run)
      assert_receive {:ok, %{"message" => "DONE"}}, 2_000
    end)

    Process.sleep(100)
    stats = Hemdal.Host.get_stats(host_id)
    assert 1 == stats.running_workers
    assert 1 == stats.waiting_workers

    spawn_monitor(fn ->
      assert {:ok, _worker} = Hemdal.Host.exec_background(host_id, long_run)
      assert_receive {:ok, %{"message" => "DONE"}}, 2_000
    end)

    Process.sleep(100)
    stats = Hemdal.Host.get_stats(host_id)
    assert 1 == stats.running_workers
    assert 2 == stats.waiting_workers

    assert_receive {:ok, %{"message" => "DONE"}}, 2_000
    assert_receive {:DOWN, _ref, :process, _pid, _reason}, 2_000
    assert_receive {:DOWN, _ref, :process, _pid, _reason}, 2_000
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

    assert %{
             "78eb75f9-2ac7-434c-a1a2-330b23c89982" => %{
               status: :up,
               max_running_workers: 1,
               running_workers: 0,
               waiting_workers: 0
             },
             "f8441510-95db-4e00-a3e0-1556bb8a778c" => %{
               status: :up,
               max_running_workers: 1,
               running_workers: 0,
               waiting_workers: 0
             }
           } == Hemdal.Host.get_all_stats()

    echo = %Hemdal.Config.Command{
      name: "hello world!",
      type: "line",
      command: ~s|sleep 1 && echo '{"status": "OK", "message": "hello world!"}'|
    }

    assert {:ok, worker} = Hemdal.Host.exec_background(host_id, echo)
    assert is_pid(worker)

    assert %{status: :up, waiting_workers: 0, running_workers: 1, max_running_workers: 1} ==
             Hemdal.Host.get_stats(host_id)

    assert_receive {:ok, %{"message" => "hello world!"}}, 5_000

    assert %{status: :up, waiting_workers: 0, running_workers: 0, max_running_workers: 1} ==
             Hemdal.Host.get_stats(host_id)
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

  test "get_stats and exists? for non-existent host" do
    assert %{status: :down} = Hemdal.Host.get_stats("non-existent-host-id")
    refute Hemdal.Host.exists?("non-existent-host-id")
    assert nil == Hemdal.Host.get_pid("non-existent-host-id")
  end

  test "decode false and error output handling" do
    assert :ok = Hemdal.Host.reload_all()
    assert [host_id, _] = Hemdal.Host.get_all()

    # decode: false with exit 0
    cmd_raw_ok = %Hemdal.Config.Command{
      name: "raw ok",
      type: "line",
      command: "echo 'plain text output'",
      decode: false
    }

    assert {:ok, %{"message" => "plain text output\n", "status" => "OK"}} =
             Hemdal.Host.exec(host_id, cmd_raw_ok)

    # decode: false with exit 1 (non-zero)
    cmd_raw_fail = %Hemdal.Config.Command{
      name: "raw fail",
      type: "line",
      command: "echo 'some error' && exit 1",
      decode: false
    }

    assert {:error, %{"status" => "UNKNOWN", "message" => "some error\n", "errorlevel" => 1}} =
             Hemdal.Host.exec(host_id, cmd_raw_fail)

    # decode: true with malformed JSON
    cmd_bad_json = %Hemdal.Config.Command{
      name: "bad json",
      type: "line",
      command: "echo '{malformed json'",
      decode: true
    }

    assert {:error, %{"status" => "UNKNOWN", "message" => "{malformed json\n"}} =
             Hemdal.Host.exec(host_id, cmd_bad_json)
  end

  test "Local file write and delete operations" do
    tmp_path = Path.join(System.tmp_dir!(), "hemdal_test_file.txt")
    assert :ok = Local.write_file([], tmp_path, "sample content")
    assert File.exists?(tmp_path)
    assert :ok = Local.delete([], tmp_path)
    refute File.exists?(tmp_path)
  end

  test "Local interactive timeout" do
    opts = [output: true, timeout: 50]
    # Spawns sleep and times out
    assert {:ok, 127, _} = Local.exec_interactive([], "cat", self(), opts)
    assert_receive {:start, _}
    assert_receive :closed
  end

  test "get_all_stats and reload_all host removal" do
    assert :ok = Hemdal.Host.reload_all()
    stats_map = Hemdal.Host.get_all_stats()
    assert is_map(stats_map)
    assert map_size(stats_map) > 0

    # Start an extra host not in config
    extra_host =
      Hemdal.Config.Host.make!(%{
        id: "extra-host-to-remove",
        name: "extra",
        module: Local
      })

    assert {:ok, _pid} = Hemdal.Host.start(extra_host)
    assert Hemdal.Host.exists?("extra-host-to-remove")

    # Reload all: extra host not in config is stopped
    assert :ok = Hemdal.Host.reload_all()
    refute Hemdal.Host.exists?("extra-host-to-remove")
  end
end
