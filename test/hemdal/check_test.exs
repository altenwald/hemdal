defmodule Hemdal.CheckTest do
  use ExUnit.Case, async: false
  require Logger

  alias Hemdal.Check

  describe "env tests" do
    setup do
      Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Env)

      host = [
        id: "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
        type: "Local",
        name: "127.0.0.1",
        max_workers: 1
      ]

      notifier = [
        metadata: %{
          pid: self()
        },
        token: "TOKEN",
        type: "Mock",
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
          broken_recheck_in_sec: 10,
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
          broken_recheck_in_sec: 10,
          retries: 1
        ]
      ])
    end

    test "get correct alert check" do
      alert_id = "aea48656-be08-4576-a2d0-2723458faefd"
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

      Hemdal.Event.Mock.stop(cap)
      Check.stop(alert.id)
    end
  end

  describe "json tests" do
    setup do
      Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Json)

      Application.put_env(:hemdal, Hemdal.Config,
        hosts_file: "test/resources/hosts_config.json",
        alerts_file: "test/resources/alerts_config.json"
      )
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
  end
end
