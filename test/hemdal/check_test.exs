defmodule Hemdal.CheckTest do
  use ExUnit.Case, async: false
  require Logger

  alias Hemdal.Check
  alias Hemdal.Config.{Alert, Command}

  describe "env tests" do
    setup do
      Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Env)

      host = [
        id: "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
        module: Hemdal.Host.Local,
        name: "127.0.0.1",
        max_workers: 1
      ]

      notifier = [
        metadata: %{
          pid: self()
        },
        token: "TOKEN",
        module: Hemdal.Notifier.Mock,
        username: "username"
      ]

      Application.put_env(:hemdal, Hemdal.Config, [
        [
          id: "aea48656-be08-4576-a2d0-2723458faefd",
          name: "valid alert check",
          host: host,
          command: [
            name: "get ok status",
            type: "line",
            command: "echo '[\"OK\", \"valid one!\"]'"
          ],
          notifiers: [notifier],
          check_in_sec: 60,
          recheck_in_sec: 1,
          broken_recheck_in_sec: 1,
          retries: 1
        ],
        [
          id: "6b6d247c-48c3-4a8c-9b4f-773f178ddc0f",
          name: "invalid alert check",
          host: host,
          command: [
            name: "get failed status",
            type: "line",
            command: "echo '[\"FAIL\", \"invalid one!\"]'"
          ],
          notifiers: [notifier],
          check_in_sec: 60,
          recheck_in_sec: 1,
          broken_recheck_in_sec: 1,
          retries: 1
        ]
      ])

      Enum.each(Check.get_all_ids(), &Check.stop/1)
      :ok
    end

    test "get correct alert check" do
      alert_id = "aea48656-be08-4576-a2d0-2723458faefd"
      {:ok, cap} = Hemdal.Event.Mock.start_link()
      alert = Hemdal.Config.get_alert_by_id!(alert_id)
      {:ok, pid} = Check.update_alert(alert)
      assert pid == Check.get_pid(alert.id)
      assert Check.exists?(alert_id)

      assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :ok}}, 1_500
      refute_receive _, 500

      status = Check.get_status(alert.id)
      assert %{"status" => :ok, "result" => %{"message" => "valid one!"}} = status
      assert %{"status" => :ok} = Check.get_status(pid)

      assert alert_id in Check.get_all_ids()
      assert Check.get_all() != []

      Hemdal.Event.Mock.stop(cap)
      Check.stop(pid)
      refute Check.exists?(alert_id)
    end

    test "get failing and broken alert check and recovery" do
      alert_id = "6b6d247c-48c3-4a8c-9b4f-773f178ddc0f"
      {:ok, cap} = Hemdal.Event.Mock.start_link()
      alert = Hemdal.Config.get_alert_by_id!(alert_id)
      {:ok, pid} = Check.update_alert(alert)
      assert pid == Check.get_pid(alert.id)

      assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :warn}}, 5_000
      assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :error}}, 5_000
      assert_receive {:notifier, %{"text" => "start to fail invalid alert" <> _}, %{pid: _pid}}
      assert_receive {:notifier, %{"text" => "broken invalid alert" <> _}, %{pid: _pid}}
      refute_receive _, 500

      status = Check.get_status(alert.id)
      assert %{"status" => :error, "result" => %{"message" => "invalid one!"}} = status

      # Now update the broken alert to a working command and verify it recovers to normal
      recovered_alert = %Alert{
        alert
        | command: %Command{
            name: "get ok status",
            type: "line",
            command: "echo '[\"OK\", \"recovered!\"]'"
          },
          broken_recheck_in_sec: 1
      }

      assert {:ok, ^pid} = Check.update_alert(recovered_alert)

      # Wait for next check to fire in broken state
      assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :ok, prev_status: :error}}, 3_000

      status = Check.get_status(alert.id)
      assert %{"status" => :ok, "result" => %{"message" => "recovered!"}} = status

      Hemdal.Event.Mock.stop(cap)
      Check.stop(alert.id)
    end

    test "disable and re-enable alert" do
      alert_id = "aea48656-be08-4576-a2d0-2723458faefd"
      {:ok, cap} = Hemdal.Event.Mock.start_link()
      alert = Hemdal.Config.get_alert_by_id!(alert_id)
      {:ok, pid} = Check.update_alert(alert)

      assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :ok}}, 1_500

      # Disable from :normal
      disabled_alert = %Alert{alert | enabled: false}
      assert {:ok, ^pid} = Check.update_alert(disabled_alert)

      assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :disabled}}, 1_000

      status = Check.get_status(alert_id)
      assert %{"status" => :disabled, "result" => %{"status" => "OFF"}} = status

      # Re-enable alert
      enabled_alert = %Alert{alert | enabled: true}
      assert {:ok, ^pid} = Check.update_alert(enabled_alert)

      assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :ok}}, 1_500

      Hemdal.Event.Mock.stop(cap)
      Check.stop(pid)
    end

    test "disable alert when in failing and broken states" do
      # Test disable from failing
      failing_alert =
        Alert.make!(%{
          id: "alert-failing-disable",
          name: "failing check",
          host: %{id: "h1", module: Hemdal.Host.Local, name: "localhost"},
          command: %{name: "fail", type: "line", command: "echo '[\"FAIL\", \"bad\"]'"},
          check_in_sec: 60,
          recheck_in_sec: 10,
          retries: 5
        })

      {:ok, cap} = Hemdal.Event.Mock.start_link()
      {:ok, pid} = Check.update_alert(failing_alert)

      assert_receive {:event, _from, %{status: :warn}}, 2_000

      # Disable from failing
      {:ok, ^pid} = Check.update_alert(%Alert{failing_alert | enabled: false})
      assert_receive {:event, _from, %{status: :disabled, prev_status: :warn}}, 1_000

      Check.stop(pid)

      # Test disable from broken
      broken_alert =
        Alert.make!(%{
          id: "alert-broken-disable",
          name: "broken check",
          host: %{id: "h2", module: Hemdal.Host.Local, name: "localhost"},
          command: %{name: "fail", type: "line", command: "echo '[\"FAIL\", \"bad\"]'"},
          check_in_sec: 60,
          recheck_in_sec: 1,
          broken_recheck_in_sec: 10,
          retries: 1
        })

      {:ok, pid2} = Check.update_alert(broken_alert)
      assert_receive {:event, _from, %{status: :warn}}, 2_000
      assert_receive {:event, _from, %{status: :error}}, 2_000

      # Disable from broken
      {:ok, ^pid2} = Check.update_alert(%Alert{broken_alert | enabled: false})
      assert_receive {:event, _from, %{status: :disabled, prev_status: :error}}, 1_000

      # Update disabled alert with another disabled config
      assert {:ok, ^pid2} =
               Check.update_alert(%Alert{broken_alert | enabled: false, name: "renamed disabled"})

      assert %{"status" => :disabled} = Check.get_status(pid2)

      Hemdal.Event.Mock.stop(cap)
      Check.stop(pid2)
    end

    test "reload_all stops alerts that were removed from configuration" do
      # Start all initial alerts
      assert :ok = Check.start_all()
      initial_ids = Check.get_all_ids()
      assert "aea48656-be08-4576-a2d0-2723458faefd" in initial_ids
      assert "6b6d247c-48c3-4a8c-9b4f-773f178ddc0f" in initial_ids

      # Remove one alert from configuration
      host = [
        id: "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
        module: Hemdal.Host.Local,
        name: "127.0.0.1",
        max_workers: 1
      ]

      Application.put_env(:hemdal, Hemdal.Config, [
        [
          id: "aea48656-be08-4576-a2d0-2723458faefd",
          name: "valid alert check",
          host: host,
          command: [
            name: "get ok status",
            type: "line",
            command: "echo '[\"OK\", \"valid one!\"]'"
          ],
          check_in_sec: 60
        ]
      ])

      # Reload all: removed alert must be stopped
      assert :ok = Check.reload_all()

      running_ids = Check.get_all_ids()
      assert "aea48656-be08-4576-a2d0-2723458faefd" in running_ids
      refute "6b6d247c-48c3-4a8c-9b4f-773f178ddc0f" in running_ids

      Enum.each(running_ids, &Check.stop/1)
    end
  end

  describe "json tests" do
    setup do
      Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Json)

      Application.put_env(:hemdal, Hemdal.Config,
        hosts_file: "test/resources/hosts_config.json",
        alerts_file: "test/resources/alerts_config.json"
      )

      Enum.each(Check.get_all_ids(), &Check.stop/1)
      :ok
    end

    test "get correct alert check" do
      alert_id = "52d13d6d-f217-4152-965d-cf5f488ceac4"
      {:ok, cap} = Hemdal.Event.Mock.start_link()
      alert = Hemdal.Config.get_alert_by_id!(alert_id)
      {:ok, pid} = Check.update_alert(alert)
      assert pid == Check.get_pid(alert.id)

      assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :ok}}, 1_500
      refute_receive _, 500

      status = Check.get_status(alert.id)
      assert %{"status" => :ok, "result" => %{"message" => "valid one!"}} = status

      Hemdal.Event.Mock.stop(cap)
      Check.stop(pid)
    end

    test "get failing and broken alert check but with a working script" do
      alert_id = "c723a511-4dad-41c1-9e03-e28d3db8586b"
      {:ok, cap} = Hemdal.Event.Mock.start_link()
      alert = Hemdal.Config.get_alert_by_id!(alert_id)
      {:ok, _pid} = Check.update_alert(alert)

      assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :warn}}, 5_000
      assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :error}}, 5_000
      refute_receive _, 500

      status = Check.get_status(alert_id)
      assert %{"status" => :error, "result" => %{"message" => "invalid one!"}} = status

      Hemdal.Event.Mock.stop(cap)
      Check.stop(alert_id)
    end

    test "failing state retries multiple times before transitioning to broken" do
      # 3 retries: warn -> warn -> warn -> error
      multi_retry_alert =
        Alert.make!(%{
          id: "alert-multi-retry",
          name: "multi retry check",
          host: %{id: "h-multi", module: Hemdal.Host.Local, name: "localhost"},
          command: %{name: "fail", type: "line", command: "echo '[\"FAIL\", \"bad\"]'"},
          check_in_sec: 60,
          recheck_in_sec: 1,
          broken_recheck_in_sec: 10,
          retries: 3
        })

      {:ok, cap} = Hemdal.Event.Mock.start_link()
      {:ok, pid} = Check.update_alert(multi_retry_alert)

      # 1st fail: transition to failing
      assert_receive {:event, _from, %{alert: %{id: "alert-multi-retry"}, status: :warn, prev_status: :ok}},
                     2_000

      # 2nd fail: retries decreases from 3 to 2
      assert_receive {:event, _from, %{alert: %{id: "alert-multi-retry"}, status: :warn, prev_status: :warn}},
                     2_000

      # 3rd fail: retries decreases from 2 to 1
      assert_receive {:event, _from, %{alert: %{id: "alert-multi-retry"}, status: :warn, prev_status: :warn}},
                     2_000

      # 4th fail: retries <= 1 -> confirmed broken
      assert_receive {:event, _from,
                      %{alert: %{id: "alert-multi-retry"}, status: :error, prev_status: :warn}},
                     2_000

      assert %{"status" => :error} = Check.get_status(pid)

      Hemdal.Event.Mock.stop(cap)
      Check.stop(pid)
    end

    test "recovery from failing state before becoming broken" do
      failing_alert =
        Alert.make!(%{
          id: "alert-failing-recover",
          name: "failing recovery check",
          host: %{id: "h-recover", module: Hemdal.Host.Local, name: "localhost"},
          command: %{name: "fail", type: "line", command: "echo '[\"FAIL\", \"bad\"]'"},
          check_in_sec: 60,
          recheck_in_sec: 1,
          retries: 5
        })

      {:ok, cap} = Hemdal.Event.Mock.start_link()
      {:ok, pid} = Check.update_alert(failing_alert)

      # 1st fail -> failing
      assert_receive {:event, _from, %{alert: %{id: "alert-failing-recover"}, status: :warn}}, 2_000

      # Update command to OK before retries expire
      recovered_alert = %Alert{
        failing_alert
        | command: %Command{name: "ok", type: "line", command: "echo '[\"OK\", \"recovered\"]'"}
      }

      {:ok, ^pid} = Check.update_alert(recovered_alert)

      # Recovers directly from warn to ok
      assert_receive {:event, _from,
                      %{alert: %{id: "alert-failing-recover"}, status: :ok, prev_status: :warn}},
                     2_000

      assert %{"status" => :ok} = Check.get_status(pid)

      Hemdal.Event.Mock.stop(cap)
      Check.stop(pid)
    end

    test "broken state stays broken on repeated failure" do
      broken_repeat_alert =
        Alert.make!(%{
          id: "alert-broken-repeat",
          name: "broken repeat check",
          host: %{id: "h-broken-repeat", module: Hemdal.Host.Local, name: "localhost"},
          command: %{name: "fail", type: "line", command: "echo '[\"FAIL\", \"bad\"]'"},
          check_in_sec: 60,
          recheck_in_sec: 1,
          broken_recheck_in_sec: 1,
          retries: 1
        })

      {:ok, cap} = Hemdal.Event.Mock.start_link()
      {:ok, pid} = Check.update_alert(broken_repeat_alert)

      # First fail -> warn, second fail -> error (broken)
      assert_receive {:event, _from, %{alert: %{id: "alert-broken-repeat"}, status: :warn}}, 2_000

      assert_receive {:event, _from,
                      %{alert: %{id: "alert-broken-repeat"}, status: :error, prev_status: :warn}},
                     2_000

      # Third fail in broken state -> still broken
      assert_receive {:event, _from,
                      %{alert: %{id: "alert-broken-repeat"}, status: :error, prev_status: :error}},
                     2_000

      Hemdal.Event.Mock.stop(cap)
      Check.stop(pid)
    end

    test "code_change callback" do
      assert {:ok, :normal, %{}} = Check.code_change("1.0.0", :normal, %{}, [])
    end
  end
end
