defmodule Hemdal.CoverageBoostTest do
  use ExUnit.Case, async: false

  alias Hemdal.Config.{Alert, Command, Host}
  alias Hemdal.Event.Notification
  alias Hemdal.Host.Local

  setup do
    Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Env)

    Application.put_env(:hemdal, Hemdal.Config, [
      [
        id: "alert-boost",
        name: "boost alert",
        host: [
          id: "host-boost-1",
          name: "localhost",
          module: Local
        ],
        command: [
          name: "echo",
          type: "line",
          command: "echo OK"
        ]
      ]
    ])

    Enum.each(Hemdal.Host.get_all(), &Hemdal.Host.stop/1)
    Enum.each(Hemdal.Check.get_all_ids(), &Hemdal.Check.stop/1)
    :ok
  end

  # Dummy failing host that fails to start
  defmodule FailingStartHost do
    use Hemdal.Host

    @impl Hemdal.Host
    def exec(_host, _cmd), do: {:error, :unreachable}

    @impl Hemdal.Host
    def write_file(_host, _file, _content), do: {:error, :cannot_write}

    @impl Hemdal.Host
    def delete(_host, _file), do: {:error, :cannot_delete}

    @impl Hemdal.Host
    def exec_interactive(_host, _cmd, _caller, _opts), do: {:error, :unsupported}

    @impl Hemdal.Host
    def shell(_host, _caller, _opts), do: {:error, :unsupported}
  end

  test "Hemdal.Check.stop with alert_id string" do
    alert =
      Alert.make!(%{
        id: "alert-stop-test",
        name: "Stop Test",
        host: %{id: "h-stop", module: Hemdal.Host.Local, name: "localhost"},
        command: %{name: "ok", type: "line", command: "echo '[\"OK\", \"ok\"]'"},
        check_in_sec: 60
      })

    assert {:ok, _pid} = Hemdal.Check.start(alert)
    assert Hemdal.Check.exists?("alert-stop-test")

    assert :ok = Hemdal.Check.stop("alert-stop-test")
    refute Hemdal.Check.exists?("alert-stop-test")
  end

  test "Hemdal.Check perform_check when host cannot start" do
    # When host is not in registry and start returns error or bad module
    failing_alert =
      Alert.make!(%{
        id: "alert-failing-host",
        name: "Failing Host Alert",
        host: %{
          id: "bad-host-id",
          module: NonExistentModule,
          name: "bad-host"
        },
        command: %{name: "cmd", type: "line", command: "echo"},
        check_in_sec: 1
      })

    {:ok, cap} = Hemdal.Event.Mock.start_link()
    {:ok, pid} = Hemdal.Check.start(failing_alert)

    # State machine attempts check -> host fails to start -> enters failing
    assert_receive {:event, _from, %{alert: %{id: "alert-failing-host"}, status: :warn}}, 7_000

    Hemdal.Event.Mock.stop(cap)
    Hemdal.Check.stop(pid)
  end

  test "Hemdal.Host decode variants and command executions" do
    host_id = "test-host-decode-variants"

    host =
      Host.make!(%{
        id: host_id,
        name: "decode-node",
        module: Hemdal.Host.Local,
        max_workers: 2
      })

    assert {:ok, _pid} = Hemdal.Host.start(host)

    # 1. Output is single string status: "OK"
    cmd_single_str = %Command{
      name: "single_str",
      type: "line",
      command: "echo '\"OK\"'",
      decode: true
    }

    assert {:ok, %{"status" => "OK", "errorlevel" => 0}} =
             Hemdal.Host.exec(host_id, cmd_single_str)

    # 2. Output is invalid JSON map without status
    cmd_no_status_map = %Command{
      name: "no_status_map",
      type: "line",
      command: "echo '{\"custom_key\": 123}'",
      decode: true
    }

    assert {:error, %{"status" => "UNKNOWN"}} =
             Hemdal.Host.exec(host_id, cmd_no_status_map)

    # 3. Output is JSON array with WARN
    cmd_warn_arr = %Command{
      name: "warn_arr",
      type: "line",
      command: "echo '[\"WARN\", \"almost full\"]' && exit 1",
      decode: true
    }

    assert {:error, %{"status" => "WARN", "message" => "almost full"}} =
             Hemdal.Host.exec(host_id, cmd_warn_arr)

    # 4. Output with exit code 2 and FAIL
    cmd_fail_arr = %Command{
      name: "fail_arr",
      type: "line",
      command: "echo '[\"FAIL\", \"critical\"]' && exit 2",
      decode: true
    }

    assert {:error, %{"status" => "FAIL", "message" => "critical"}} =
             Hemdal.Host.exec(host_id, cmd_fail_arr)

    # 5. Interactive command with no caller -> impossible combination
    cmd_interactive_no_caller = %Command{
      name: "interactive",
      type: "line",
      command: "cat",
      interactive: true
    }

    assert {:error, %{"message" => "Impossible combination"}} =
             Hemdal.Host.exec(host_id, cmd_interactive_no_caller, [])

    Hemdal.Host.stop(host_id)
  end

  test "Hemdal.Event.Notification with disabled status" do
    alert =
      Alert.make!(%{
        id: "alert-notif-disabled",
        name: "Disabled Notification",
        host: %{id: "h", name: "h", module: Hemdal.Host.Local},
        command: %{name: "c", type: "line", command: "echo"},
        notifiers: [
          %{
            module: Hemdal.Notifier.Mock,
            token: "TOKEN",
            username: "Bot",
            log_level: "debug",
            metadata: %{pid: self()}
          }
        ]
      })

    event = %Hemdal.Event{
      alert: alert,
      status: :disabled,
      prev_status: :ok,
      fail_duration: 0,
      last_update: NaiveDateTime.utc_now(),
      metadata: %{"status" => "OFF", "message" => "disabled"}
    }

    assert {:noreply, [], _} = Notification.handle_events([event], self(), %{})
    assert_receive {:notifier, %{"text" => "disabled Disabled Notification on h"}, _}
  end

  test "Hemdal.Host.Local behavior transaction and callbacks" do
    assert :ok = Local.transaction(%{}, fn _ -> :ok end)
  end

  test "Hemdal.Host start_all and interactive exec with caller" do
    assert :ok = Hemdal.Host.start_all()
    [host_id | _] = Hemdal.Host.get_all()

    interactive_cmd = %Command{
      name: "interactive",
      type: "shell",
      command: "cat",
      interactive: true
    }

    assert {:ok, runner} = Hemdal.Host.exec_background(host_id, interactive_cmd, caller: self())
    assert is_pid(runner)
    assert_receive {:start, worker}
    send(worker, :close)
    assert_receive :closed

    # exec_background with string list
    script_cmd = %Command{
      name: "script",
      type: "line",
      command: "echo OK",
      decode: true
    }

    assert {:ok, _pid} = Hemdal.Host.exec_background(host_id, script_cmd, ["extra_arg"])

    # Script without shebang (tests fallback shell @default_shell)
    script_no_shebang = %Command{
      name: "no_shebang",
      type: "script",
      command: "echo '[\"OK\", \"no shebang\"]'",
      interactive: false,
      decode: true
    }

    assert {:ok, %{"message" => "no shebang"}} = Hemdal.Host.exec(host_id, script_no_shebang)

    # Interactive script (type: "script", interactive: true)
    interactive_script = %Command{
      name: "interactive_script",
      type: "script",
      command: "cat",
      interactive: true
    }

    assert {:ok, _runner2} = Hemdal.Host.exec_background(host_id, interactive_script, caller: self())
    assert_receive {:start, worker2}
    send(worker2, :close)
    assert_receive :closed
  end
end
