defmodule Hemdal.ConfigTest do
  use ExUnit.Case, async: false

  describe "env" do
    setup do
      Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Env)
    end

    test "valid config" do
      Application.put_env(:hemdal, Hemdal.Config, [
        [
          id: "aea48656-be08-4576-a2d0-2723458faefd",
          name: "valid alert check",
          host: [
            id: "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
            type: "Local",
            name: "127.0.0.1",
            max_workers: 1,
            credential: [
              id: "5414270f-9752-441b-883e-4b3c1bae5061",
              type: "rsa",
              username: "manuel",
              password: "mysecret"
            ]
          ],
          command: [
            id: "c5c090b2-7b6a-487e-87b8-57788bffaffe",
            name: "get ok status",
            command_type: "line",
            command: "echo '[\"OK\", \"valid one!\"]'"
          ],
          notifiers: [[
            id: "82d3a827-08fc-41be-9f6d-04d66dddd2a4",
            metadata: %{
              pid: self()
            },
            token: "TOKEN",
            type: "Mock",
            username: "username"
          ]],
          check_in_sec: 60,
          recheck_in_sec: 1,
          broken_recheck_in_sec: 10,
          retries: 1
        ]
      ])

      [alert] = Hemdal.Config.get_all_alerts()
      assert "aea48656-be08-4576-a2d0-2723458faefd" == alert.id
      assert "valid alert check" == alert.name
      assert %Hemdal.Config.Host{id: "2a8572d4-ceb3-4200-8b29-dd1f21b50e54", type: "Local"} = alert.host
      assert %Hemdal.Config.Alert.Command{command_type: "line"} = alert.command
      assert [%Hemdal.Config.Notifier{id: "82d3a827-08fc-41be-9f6d-04d66dddd2a4", type: "Mock"}] = alert.notifiers
      assert 1 == alert.retries
      assert 60 == alert.check_in_sec
      assert %Hemdal.Config.Host.Credential{type: "rsa"} = alert.host.credential
    end
  end

  describe "json" do
    setup do
      Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Json)
      Application.put_env(:hemdal, Hemdal.Config,
        hosts_file: "test/resources/single_full_host.json",
        alerts_file: "test/resources/single_full_alert.json"
      )
    end

    test "valid config" do
      [alert] = Hemdal.Config.get_all_alerts()
      assert "2f1cc590-624b-4246-b1d4-2bc97416b321" == alert.id
      assert "single valid check" == alert.name
      assert %Hemdal.Config.Host{type: "Trooper"} = alert.host
      assert %Hemdal.Config.Alert.Command{command_type: "line"} = alert.command
      assert [%Hemdal.Config.Notifier{id: "4738acee-7ac1-4c18-a003-9be23fd9c13e", type: "Mock"}] = alert.notifiers
      assert 5 == alert.retries
      assert 60 == alert.check_in_sec
      assert %Hemdal.Config.Host.Credential{type: "rsa"} = alert.host.credential
    end

    test "valid hosts" do
      [host1, host2] =
        Hemdal.Config.get_all_hosts()
        |> Enum.sort_by(& &1.id)

      assert "01acc056-9412-455b-8372-9726385ebb4b" == host1.id
      assert "b827b01e-236a-4463-bde8-ee18ff3c80fe" == host2.id
    end
  end
end
