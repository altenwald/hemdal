defmodule Hemdal.HostLifecycleTest do
  use ExUnit.Case, async: false

  # A custom test host module to verify options / IP tracking across host updates
  # and provide deterministic synchronization via message passing without Process.sleep.
  defmodule CustomTrackerHost do
    use Hemdal.Host

    @impl Hemdal.Host
    def exec(host, _cmd) do
      maybe_signal_test(get_opt(host, :test_pid))
      ip = get_opt(host, :ip) || "unknown"
      name = host.name
      {:ok, 0, Jason.encode!(%{"status" => "OK", "message" => "connected to #{name}@#{ip}"})}
    end

    defp maybe_signal_test(pid) when is_pid(pid) do
      send(pid, {:worker_started, self()})

      receive do
        :continue -> :ok
      end
    end

    defp maybe_signal_test(_), do: :ok

    defp get_opt(host, key) do
      case host.options do
        opts when is_list(opts) -> Keyword.get(opts, key)
        opts when is_map(opts) -> Map.get(opts, key) || Map.get(opts, to_string(key))
        _ -> nil
      end
    end

    @impl Hemdal.Host
    def exec_interactive(_host, _cmd, _caller, _opts), do: {:error, :unsupported}

    @impl Hemdal.Host
    def shell(_host, _caller, _opts), do: {:error, :unsupported}

    @impl Hemdal.Host
    def write_file(_host, _file, _content), do: :ok

    @impl Hemdal.Host
    def delete(_host, _file), do: :ok
  end

  setup do
    Enum.each(Hemdal.Host.get_all(), &Hemdal.Host.stop/1)
    :ok
  end

  test "host updates connection data (IP / options / name) and uses new data in subsequent executions" do
    host_id = "test-host-ip-update"

    initial_host =
      Hemdal.Config.Host.make!(%{
        id: host_id,
        name: "node-1",
        module: CustomTrackerHost,
        options: [ip: "10.0.0.1"],
        max_workers: 2
      })

    # 1. Start initial host
    assert {:ok, pid1} = Hemdal.Host.start(initial_host)
    assert Hemdal.Host.exists?(host_id)

    cmd = %Hemdal.Config.Command{name: "ping", type: "line", command: "ping"}
    assert {:ok, %{"message" => "connected to node-1@10.0.0.1"}} = Hemdal.Host.exec(host_id, cmd)

    # 2. Update host data (new IP and new name) while running
    updated_host =
      Hemdal.Config.Host.make!(%{
        id: host_id,
        name: "node-1-renamed",
        module: CustomTrackerHost,
        options: [ip: "192.168.1.100"],
        max_workers: 2
      })

    assert {:ok, ^pid1} = Hemdal.Host.update_host(updated_host)

    # 3. Verify next execution immediately uses the updated IP and name
    assert {:ok, %{"message" => "connected to node-1-renamed@192.168.1.100"}} =
             Hemdal.Host.exec(host_id, cmd)

    Hemdal.Host.stop(host_id)
  end

  test "updating max_workers from 1 to 5 immediately drains queued tasks" do
    host_id = "test-host-queue-drain"

    host =
      Hemdal.Config.Host.make!(%{
        id: host_id,
        name: "slow-node",
        module: CustomTrackerHost,
        options: [test_pid: self()],
        max_workers: 1
      })

    assert {:ok, _pid} = Hemdal.Host.start(host)

    cmd = %Hemdal.Config.Command{name: "block", type: "line", command: "block"}

    # Launch 1 job (occupies the single worker)
    assert {:ok, _w1} = Hemdal.Host.exec_background(host_id, cmd)
    assert_receive {:worker_started, pid1}, 1_000

    # Queue 2 more jobs asynchronously (they wait for available worker capacity)
    t2 = Task.async(fn -> Hemdal.Host.exec_background(host_id, cmd) end)
    t3 = Task.async(fn -> Hemdal.Host.exec_background(host_id, cmd) end)

    # Update max_workers to 5
    updated_host =
      Hemdal.Config.Host.make!(%{
        id: host_id,
        name: "fast-node",
        module: CustomTrackerHost,
        options: [test_pid: self()],
        max_workers: 5
      })

    assert {:ok, _pid} = Hemdal.Host.update_host(updated_host)

    # Verify that both queued workers were immediately launched (deterministic signal)
    assert_receive {:worker_started, pid2}, 1_000
    assert_receive {:worker_started, pid3}, 1_000

    assert {:ok, _w2} = Task.await(t2, 1_000)
    assert {:ok, _w3} = Task.await(t3, 1_000)

    stats = Hemdal.Host.get_stats(host_id)
    assert 3 == stats.running_workers
    assert 0 == stats.waiting_workers
    assert 5 == stats.max_running_workers

    # Release workers cleanly
    send(pid1, :continue)
    send(pid2, :continue)
    send(pid3, :continue)

    Hemdal.Host.stop(host_id)
  end

  test "updating max_workers from 1 to :infinity drains queued tasks" do
    host_id = "test-host-infinity"

    host =
      Hemdal.Config.Host.make!(%{
        id: host_id,
        name: "limited-node",
        module: CustomTrackerHost,
        options: [test_pid: self()],
        max_workers: 1
      })

    assert {:ok, _pid} = Hemdal.Host.start(host)

    cmd = %Hemdal.Config.Command{name: "block", type: "line", command: "block"}

    assert {:ok, _w1} = Hemdal.Host.exec_background(host_id, cmd)
    assert_receive {:worker_started, pid1}, 1_000

    t2 = Task.async(fn -> Hemdal.Host.exec_background(host_id, cmd) end)
    t3 = Task.async(fn -> Hemdal.Host.exec_background(host_id, cmd) end)

    # Update max_workers to :infinity
    updated_host =
      Hemdal.Config.Host.make!(%{
        id: host_id,
        name: "infinite-node",
        module: CustomTrackerHost,
        options: [test_pid: self()],
        max_workers: :infinity
      })

    assert {:ok, _pid} = Hemdal.Host.update_host(updated_host)

    # Both queued tasks immediately start
    assert_receive {:worker_started, pid2}, 1_000
    assert_receive {:worker_started, pid3}, 1_000

    assert {:ok, _w2} = Task.await(t2, 1_000)
    assert {:ok, _w3} = Task.await(t3, 1_000)

    stats = Hemdal.Host.get_stats(host_id)
    assert 3 == stats.running_workers
    assert 0 == stats.waiting_workers
    assert :infinity == stats.max_running_workers

    send(pid1, :continue)
    send(pid2, :continue)
    send(pid3, :continue)

    Hemdal.Host.stop(host_id)
  end

  test "updating max_workers from :infinity to a fixed number" do
    host_id = "test-host-from-infinity"

    host =
      Hemdal.Config.Host.make!(%{
        id: host_id,
        name: "infinite-node",
        module: Hemdal.Host.Local,
        max_workers: :infinity
      })

    assert {:ok, _pid} = Hemdal.Host.start(host)

    updated_host =
      Hemdal.Config.Host.make!(%{
        id: host_id,
        name: "limited-node",
        module: Hemdal.Host.Local,
        max_workers: 3
      })

    assert {:ok, _pid} = Hemdal.Host.update_host(updated_host)

    stats = Hemdal.Host.get_stats(host_id)
    assert 3 == stats.max_running_workers

    Hemdal.Host.stop(host_id)
  end

  test "command arguments are properly passed to script execution" do
    host_id = "test-host-args"

    host =
      Hemdal.Config.Host.make!(%{
        id: host_id,
        name: "args-node",
        module: Hemdal.Host.Local,
        max_workers: 2
      })

    assert {:ok, _pid} = Hemdal.Host.start(host)

    script_cmd = %Hemdal.Config.Command{
      name: "check_with_args",
      type: "script",
      command: """
      #!/bin/bash
      ARG1="$1"
      ARG2="$2"
      echo '["OK", "'$ARG1' '$ARG2'"]'
      """,
      decode: true
    }

    # Test passing args via keyword list
    assert {:ok, %{"message" => "hello world"}} =
             Hemdal.Host.exec(host_id, script_cmd, args: ["hello", "world"])

    # Test passing args directly as string list
    assert {:ok, %{"message" => "foo bar"}} =
             Hemdal.Host.exec(host_id, script_cmd, ["foo", "bar"])

    Hemdal.Host.stop(host_id)
  end
end
