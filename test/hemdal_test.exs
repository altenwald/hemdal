defmodule HemdalTest do
  use ExUnit.Case, async: false

  setup do
    Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Env)
  end

  test "get all alerts" do
    alert_id = "325cf8b7-6a9d-4c79-973d-df940d3df1c2"

    Application.put_env(:hemdal, Hemdal.Config, [
      [
        id: alert_id,
        name: "valid alert check",
        enabled: false,
        host: [
          id: "ec8fff22-41c2-4245-8a7b-5157d40c33a7",
          type: "Local",
          name: "127.0.0.1"
        ],
        command: [
          name: "get ok status",
          type: "line",
          command: "echo '[\"OK\", \"valid one!\"]'"
        ],
        check_in_sec: 60,
        recheck_in_sec: 1,
        broken_recheck_in_sec: 10,
        retries: 1
      ]
    ])

    assert [] == Hemdal.get_all_alerts()
    assert {:ok, _pid} = Hemdal.start_alert!(alert_id)

    assert [
             %{
               "alert" => %{
                 "command" => "get ok status",
                 "host" => "127.0.0.1",
                 "id" => ^alert_id,
                 "name" => "valid alert check"
               },
               "last_update" => _last_update,
               "result" => %{
                 "message" => "disabled",
                 "status" => "OFF"
               },
               "status" => :disabled
             }
           ] = Hemdal.get_all_alerts()

    Hemdal.Check.stop(alert_id)
  end

  test "reload all" do
    alert_id = "5b7bcf07-53b9-4248-b6ea-fc2881431435"

    Application.put_env(:hemdal, Hemdal.Config, [
      [
        id: alert_id,
        name: "valid alert check",
        enabled: false,
        host: [
          id: "1f694dc3-245a-4d35-b266-85bf126c8bb7",
          type: "Local",
          name: "127.0.0.1"
        ],
        command: [
          name: "get ok status",
          type: "line",
          command: "echo '[\"OK\", \"valid one!\"]'"
        ],
        check_in_sec: 60,
        recheck_in_sec: 1,
        broken_recheck_in_sec: 10,
        retries: 1
      ]
    ])

    assert {:ok, _pid} = Hemdal.start_alert!(alert_id)

    assert [
             %{
               "alert" => %{
                 "command" => "get ok status",
                 "host" => "127.0.0.1",
                 "id" => ^alert_id,
                 "name" => "valid alert check"
               },
               "result" => %{
                 "message" => "disabled",
                 "status" => "OFF"
               },
               "status" => :disabled
             }
           ] = Hemdal.get_all_alerts()

    Application.put_env(:hemdal, Hemdal.Config, [
      [
        id: alert_id,
        name: "valid reloaded alert check",
        enabled: false,
        host: [
          id: "ec8fff22-41c2-4245-8a7b-5157d40c33a7",
          type: "Local",
          name: "localhost"
        ],
        command: [
          name: "get ok status",
          type: "line",
          command: "echo '[\"OK\", \"valid one!\"]'"
        ],
        check_in_sec: 60,
        recheck_in_sec: 1,
        broken_recheck_in_sec: 10,
        retries: 1
      ]
    ])

    assert :ok == Hemdal.reload_all()

    assert [
             %{
               "alert" => %{
                 "command" => "get ok status",
                 "host" => "localhost",
                 "id" => ^alert_id,
                 "name" => "valid reloaded alert check"
               },
               "result" => %{
                 "message" => "disabled",
                 "status" => "OFF"
               },
               "status" => :disabled
             }
           ] = Hemdal.get_all_alerts()

    Hemdal.Check.stop(alert_id)
  end
end
