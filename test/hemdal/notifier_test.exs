defmodule Hemdal.NotifierTest do
  use ExUnit.Case, async: false

  alias Hemdal.Config.{Alert, Notifier}
  alias Hemdal.Notifier.{Mattermost, Slack}

  setup do
    test_pid = self()

    Req.Test.stub(Hemdal.Notifier, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded_body = if body != "", do: Jason.decode!(body), else: nil

      send(
        test_pid,
        {:captured_http,
         %{
           host: conn.host,
           path: conn.request_path,
           method: conn.method,
           headers: Map.new(conn.req_headers),
           body: decoded_body
         }}
      )

      url = conn.request_path
      host = conn.host

      cond do
        String.contains?(url, "/services/ok") ->
          Req.Test.text(conn, "ok")

        String.contains?(url, "/services/fail") ->
          conn
          |> Plug.Conn.put_status(500)
          |> Req.Test.text("internal error")

        String.contains?(host, "mattermost.example.com") ->
          conn
          |> Plug.Conn.put_status(201)
          |> Req.Test.json(%{"id" => "123"})

        String.contains?(host, "mattermost.fail.com") ->
          conn
          |> Plug.Conn.put_status(400)
          |> Req.Test.json(%{"error" => "bad request"})

        true ->
          Req.Test.text(conn, "ok")
      end
    end)

    :ok
  end

  defp make_alert do
    Alert.make!(%{
      id: "alert-1",
      name: "Disk Full Check",
      host: %{
        id: "host-1",
        name: "db-server",
        module: Hemdal.Host.Local
      },
      command: %{
        name: "check_disk",
        type: "line",
        command: "echo OK"
      }
    })
  end

  test "notifier attach and field callbacks" do
    field1 = Hemdal.Notifier.field("Host", "db-server")
    assert %{"title" => "Host", "value" => "db-server", "short" => true} == field1

    field2 = Hemdal.Notifier.field("Desc", "Details", false)
    assert %{"title" => "Desc", "value" => "Details", "short" => false} == field2

    att = Hemdal.Notifier.attach("Alert", "#009900", [field1, field2], "http://img.png")

    assert %{
             "title" => "Alert",
             "color" => "#009900",
             "fields" => [^field1, ^field2],
             "img_url" => "http://img.png"
           } = att
  end

  test "notifier send formats messages correctly for all statuses" do
    alert = make_alert()

    notifier =
      Notifier.make!(%{
        token: "TOKEN",
        module: Hemdal.Notifier.Mock,
        username: "CustomBot",
        metadata: %{pid: self(), channel: "#ops", icon: ":warning:"}
      })

    # Test :disabled
    assert :ok = Hemdal.Notifier.send(notifier, :disabled, :ok, alert, %{"message" => "off"}, 0)
    assert_receive {:notifier, %{"text" => "disabled Disk Full Check on db-server"}, _}

    # Test :ok from :ok
    assert :ok = Hemdal.Notifier.send(notifier, :ok, :ok, alert, %{"status" => "OK"}, nil)
    assert_receive {:notifier, %{"text" => "successful run Disk Full Check on db-server"}, _}

    # Test :ok from :warn
    assert :ok = Hemdal.Notifier.send(notifier, :ok, :warn, alert, %{"status" => "OK"}, 5)

    assert_receive {:notifier, %{"text" => "successful again run Disk Full Check on db-server after 5 sec"},
                    _}

    # Test :ok from :error
    assert :ok = Hemdal.Notifier.send(notifier, :ok, :error, alert, %{"status" => "OK"}, 12)
    assert_receive {:notifier, %{"text" => "recovered run Disk Full Check on db-server after 12 sec"}, _}

    # Test :warn from :ok
    assert :ok = Hemdal.Notifier.send(notifier, :warn, :ok, alert, %{"status" => "WARN"}, 0)
    assert_receive {:notifier, %{"text" => "start to fail Disk Full Check on db-server"}, _}

    # Test :warn from :warn
    assert :ok = Hemdal.Notifier.send(notifier, :warn, :warn, alert, %{"status" => "WARN"}, 10)
    assert_receive {:notifier, %{"text" => "failing Disk Full Check on db-server lasting 10 sec"}, _}

    # Test :error from :warn
    assert :ok = Hemdal.Notifier.send(notifier, :error, :warn, alert, %{"status" => "FAIL"}, 15)
    assert_receive {:notifier, %{"text" => "broken Disk Full Check on db-server lasting 15 sec"}, _}

    # Test :error from :error
    assert :ok = Hemdal.Notifier.send(notifier, :error, :error, alert, %{"status" => "FAIL"}, 30)
    assert_receive {:notifier, %{"text" => "still broken Disk Full Check on db-server lasting 30 sec"}, _}

    # Test unknown/fallback status
    assert :ok = Hemdal.Notifier.send(notifier, :custom_status, nil, alert, %{}, 5)
    assert_receive {:notifier, %{"text" => "custom_status Disk Full Check on db-server lasting 5 sec"}, _}
  end

  test "Slack notifier sends message successfully and captures exact payload" do
    msg = %{
      "text" => "Disk usage is 95%",
      "channel" => "#monitoring",
      "username" => "HemdalBot",
      "icon_emoji" => ":warning:",
      "attachments" => [
        %{
          "title" => "Disk Full Check",
          "color" => "#990000",
          "fields" => [%{"title" => "Host", "value" => "db-server", "short" => true}]
        }
      ]
    }

    assert :ok = Slack.send(msg, "/services/ok/T000/B000/XXXX", %{})

    assert_receive {:captured_http, req}
    assert req.host == "hooks.slack.com"
    assert req.path == "/services/ok/T000/B000/XXXX"
    assert req.method == "POST"
    assert req.body == msg
  end

  test "Slack notifier triggered via Hemdal.Notifier.send sends correct format" do
    alert = make_alert()

    notifier =
      Notifier.make!(%{
        token: "/services/ok/T1/B1/K1",
        module: Hemdal.Notifier.Slack,
        username: "SlackHemdal",
        metadata: %{"channel" => "#critical", "icon" => ":fire:"}
      })

    assert :ok = Hemdal.Notifier.send(notifier, :error, :warn, alert, %{"description" => "high disk IO"}, 42)

    assert_receive {:captured_http, req}
    assert req.host == "hooks.slack.com"
    assert req.path == "/services/ok/T1/B1/K1"
    assert req.body["username"] == "SlackHemdal"
    assert req.body["channel"] == "#critical"
    assert req.body["icon_emoji"] == ":fire:"
    assert req.body["text"] == "broken Disk Full Check on db-server lasting 42 sec"

    [attachment] = req.body["attachments"]
    assert attachment["title"] == "Disk Full Check"
    assert attachment["color"] == "#990000"
  end

  test "Slack notifier handles HTTP error responses" do
    msg = %{"text" => "fail", "channel" => "#general", "attachments" => []}
    assert {:error, %{status: 500}} = Slack.send(msg, "/services/fail", %{})
  end

  test "Slack notifier handles connection failure" do
    Req.Test.stub(Hemdal.Notifier, fn conn ->
      Req.Test.transport_error(conn, :nxdomain)
    end)

    msg = %{"text" => "error", "channel" => "#general", "attachments" => []}
    assert {:error, %Req.TransportError{reason: :nxdomain}} = Slack.send(msg, "/services/down", %{})
  end

  test "Mattermost notifier sends message successfully and captures exact payload" do
    msg = %{
      "text" => "CPU spike detected",
      "channel" => "ops-channel-id",
      "attachments" => [
        %{
          "title" => "CPU Check",
          "color" => "#FFDA55",
          "fields" => [%{"title" => "Load", "value" => "4.5", "short" => true}]
        }
      ]
    }

    metadata = %{"base_url" => "https://mattermost.example.com/api/v4"}
    assert :ok = Mattermost.send(msg, "token-secret-123", metadata)

    assert_receive {:captured_http, req}
    assert req.host == "mattermost.example.com"
    assert req.path == "/api/v4/posts"
    assert req.method == "POST"
    assert req.headers["authorization"] == "bearer token-secret-123"

    assert req.body == %{
             "channel_id" => "ops-channel-id",
             "message" => "CPU spike detected",
             "props" => %{
               "attachments" => [
                 %{
                   "title" => "CPU Check",
                   "color" => "#FFDA55",
                   "fields" => [%{"title" => "Load", "value" => "4.5", "short" => true}]
                 }
               ]
             }
           }
  end

  test "Mattermost notifier triggered via Hemdal.Notifier.send sends correct format" do
    alert = make_alert()

    notifier =
      Notifier.make!(%{
        token: "mm-token-xyz",
        module: Hemdal.Notifier.Mattermost,
        username: "MattermostHemdal",
        metadata: %{
          "base_url" => "https://mattermost.example.com/api/v4",
          "channel" => "channel-sys-alerts"
        }
      })

    assert :ok = Hemdal.Notifier.send(notifier, :ok, :error, alert, %{"description" => "disk freed"}, 18)

    assert_receive {:captured_http, req}
    assert req.host == "mattermost.example.com"
    assert req.path == "/api/v4/posts"
    assert req.headers["authorization"] == "bearer mm-token-xyz"
    assert req.body["channel_id"] == "channel-sys-alerts"
    assert req.body["message"] == "recovered run Disk Full Check on db-server after 18 sec"

    [attachment] = req.body["props"]["attachments"]
    assert attachment["title"] == "Disk Full Check"
    assert attachment["color"] == "#009900"
  end

  test "Mattermost notifier handles HTTP error responses" do
    msg = %{"text" => "hello", "channel" => "monitoring", "attachments" => []}
    metadata = %{base_url: "https://mattermost.fail.com/api/v4"}
    assert {:error, %{status: 400}} = Mattermost.send(msg, "token-123", metadata)
  end

  test "Mattermost notifier handles connection failure" do
    Req.Test.stub(Hemdal.Notifier, fn conn ->
      Req.Test.transport_error(conn, :econnrefused)
    end)

    msg = %{"text" => "error", "channel" => "monitoring", "attachments" => []}
    assert {:error, %Req.TransportError{reason: :econnrefused}} = Mattermost.send(msg, "token-123", %{})
  end
end
