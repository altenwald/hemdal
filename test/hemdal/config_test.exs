defmodule Hemdal.ConfigTest do
  use ExUnit.Case, async: false

  alias Hemdal.Config.{Alert, Backend, Command, Host, MaxWorkers, Module, Options}
  alias Hemdal.Host.Local

  describe "env" do
    setup do
      Application.put_env(:hemdal, :config_module, Backend.Env)
    end

    test "valid config" do
      Application.put_env(:hemdal, Hemdal.Config, [
        [
          id: "aea48656-be08-4576-a2d0-2723458faefd",
          name: "valid alert check",
          host: [
            id: "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
            module: Hemdal.Host.Local,
            name: "localhost",
            max_workers: 1,
            options: [
              type: "rsa",
              username: "manuel",
              password: "mysecret"
            ]
          ],
          command: [
            name: "get ok status",
            type: "line",
            command: "echo '[\"OK\", \"valid one!\"]'"
          ],
          notifiers: [
            [
              metadata: %{
                pid: self()
              },
              token: "TOKEN",
              module: Hemdal.Notifier.Mock,
              username: "username"
            ]
          ],
          check_in_sec: 60,
          recheck_in_sec: 1,
          broken_recheck_in_sec: 10,
          retries: 1
        ]
      ])

      [alert] = Hemdal.Config.get_all_alerts()
      assert "aea48656-be08-4576-a2d0-2723458faefd" == alert.id
      assert "valid alert check" == alert.name

      assert %Hemdal.Config.Host{
               id: "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
               module: Hemdal.Host.Local
             } = alert.host

      assert %Hemdal.Config.Command{type: "line"} = alert.command

      assert [%Hemdal.Config.Notifier{module: Hemdal.Notifier.Mock}] = alert.notifiers

      assert 1 == alert.retries
      assert 60 == alert.check_in_sec
    end
  end

  describe "json" do
    setup do
      Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Json)

      # Create temporary certificate files for testing file: prefix resolution
      tmp_cert = Path.join(System.tmp_dir!(), "test_cert_key.pem")
      tmp_pub = Path.join(System.tmp_dir!(), "test_cert_pub.pem")
      File.write!(tmp_cert, "-----BEGIN CERT KEY-----")
      File.write!(tmp_pub, "-----BEGIN CERT PUB-----")

      hosts_content = """
      [
        {
          "id": "01acc056-9412-455b-8372-9726385ebb4b",
          "name": "My Machine 1",
          "max_workers": 1,
          "credential": {
            "cert_key": "file:#{tmp_cert}",
            "cert_pub": "file:#{tmp_pub}"
          }
        },
        {
          "id": "b827b01e-236a-4463-bde8-ee18ff3c80fe",
          "name": "My Machine 2",
          "max_workers": 1,
          "options": {
            "cert_key": "file:#{tmp_cert}"
          }
        }
      ]
      """

      tmp_hosts_file = Path.join(System.tmp_dir!(), "test_hosts_config.json")
      File.write!(tmp_hosts_file, hosts_content)

      Application.put_env(:hemdal, Hemdal.Config,
        hosts_file: tmp_hosts_file,
        alerts_file: "test/resources/single_full_alert.json"
      )

      on_exit(fn ->
        File.rm(tmp_cert)
        File.rm(tmp_pub)
        File.rm(tmp_hosts_file)
      end)

      :ok
    end

    test "valid config with file credentials and options" do
      [alert] = Hemdal.Config.get_all_alerts()
      assert "2f1cc590-624b-4246-b1d4-2bc97416b321" == alert.id
      assert "single valid check" == alert.name
      assert %Hemdal.Config.Host{module: Hemdal.Host.Local} = alert.host
      assert %Hemdal.Config.Command{type: "line"} = alert.command

      assert [%Hemdal.Config.Notifier{module: Hemdal.Notifier.Mock}] = alert.notifiers

      assert 5 == alert.retries
      assert 60 == alert.check_in_sec
    end

    test "valid hosts with file credential resolution" do
      [host1, host2] =
        Hemdal.Config.get_all_hosts()
        |> Enum.sort_by(& &1.id)

      assert "01acc056-9412-455b-8372-9726385ebb4b" == host1.id
      assert "b827b01e-236a-4463-bde8-ee18ff3c80fe" == host2.id

      # Verify options with file resolution
      assert %{"cert_key" => "-----BEGIN CERT KEY-----"} = host2.options
    end

    test "json backend with unmatched host_id" do
      tmp_alert_file = Path.join(System.tmp_dir!(), "test_unmatched_alert.json")

      File.write!(
        tmp_alert_file,
        ~s|[{"id": "a-1", "name": "A", "host_id": "non-existent-host", "command": {"name": "c", "type": "line", "command": "echo"}}]|
      )

      Application.put_env(:hemdal, Hemdal.Config,
        hosts_file: "test/resources/hosts_config.json",
        alerts_file: tmp_alert_file
      )

      assert [%Hemdal.Config.Alert{id: "a-1", host: %Hemdal.Config.Host{id: "non-existent-host"}}] =
               Hemdal.Config.get_all_alerts()

      File.rm(tmp_alert_file)
    end
  end

  describe "Construct Types" do
    test "Options.cast" do
      assert {:ok, []} = Options.cast([])
      assert {:ok, [foo: "bar"]} = Options.cast(foo: "bar")
      assert {:ok, %{foo: "bar"}} = Options.cast(%{foo: "bar"})
      assert :error = Options.cast("invalid")
      assert :error = Options.cast(123)
    end

    test "Module.cast" do
      assert {:ok, Local} = Module.cast(Local)
      assert {:ok, Local} = Module.cast("Hemdal.Host.Local")
      assert {:ok, Local} = Module.cast("Elixir.Hemdal.Host.Local")
      assert {:error, "unknown module UnknownModule"} = Module.cast("UnknownModule")
      assert :error = Module.cast(123)
    end

    test "MaxWorkers.cast" do
      assert {:ok, :infinity} = MaxWorkers.cast(:infinity)
      assert {:ok, :infinity} = MaxWorkers.cast("infinity")
      assert {:ok, 10} = MaxWorkers.cast(10)
      assert {:ok, 0} = MaxWorkers.cast(0)
      assert :error = MaxWorkers.cast(-1)
      assert :error = MaxWorkers.cast("invalid")
      assert :error = MaxWorkers.cast(:invalid)
    end
  end
end
