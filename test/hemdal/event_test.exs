defmodule Hemdal.EventTest do
  use ExUnit.Case, async: false

  alias Hemdal.Config.Alert
  alias Hemdal.Event
  alias Hemdal.Event.{Log, Notification}
  alias Hemdal.Host.Local

  setup do
    alert =
      Alert.make!(%{
        id: "alert-event-test",
        name: "Memory Check",
        host: %{
          id: "host-event-test",
          name: "server1",
          module: Local
        },
        command: %{
          name: "check_mem",
          type: "line",
          command: "echo OK"
        },
        notifiers: [
          %{
            module: Hemdal.Notifier.Mock,
            token: "TOKEN",
            username: "TestBot",
            log_level: "debug",
            metadata: %{pid: self()}
          },
          %{
            module: Hemdal.Notifier.Mock,
            token: "TOKEN",
            username: "WarnBot",
            log_level: "warn",
            metadata: %{pid: self()}
          },
          %{
            module: Hemdal.Notifier.Mock,
            token: "TOKEN",
            username: "ErrorBot",
            log_level: "error",
            metadata: %{pid: self()}
          }
        ]
      })

    %{alert: alert}
  end

  test "Event.notify broadcasts to Event.Mock consumer", %{alert: alert} do
    {:ok, mock_consumer} = Hemdal.Event.Mock.start_link()

    event = %Event{
      alert: alert,
      status: :ok,
      prev_status: :ok,
      fail_duration: 0,
      last_update: NaiveDateTime.utc_now(),
      metadata: %{"message" => "all ok"}
    }

    Event.notify(event)

    assert_receive {:event, _from, ^event}, 1_000

    Hemdal.Event.Mock.stop(mock_consumer)
  end

  test "Event.Notification filters events by log_level correctly", %{alert: alert} do
    # 1. :ok -> :ok: Only "debug" should notify
    event1 = %Event{
      alert: alert,
      status: :ok,
      prev_status: :ok,
      fail_duration: 0,
      last_update: NaiveDateTime.utc_now(),
      metadata: %{"message" => "ok"}
    }

    Event.notify(event1)
    assert_receive {:notifier, %{"username" => "TestBot"}, _}, 1_000
    refute_receive {:notifier, %{"username" => "WarnBot"}, _}, 100
    refute_receive {:notifier, %{"username" => "ErrorBot"}, _}, 100

    # 2. :ok -> :warn: "debug" and "warn" should notify, "error" should NOT
    event2 = %Event{
      alert: alert,
      status: :warn,
      prev_status: :ok,
      fail_duration: 0,
      last_update: NaiveDateTime.utc_now(),
      metadata: %{"message" => "high mem"}
    }

    Event.notify(event2)
    assert_receive {:notifier, %{"username" => "TestBot"}, _}, 1_000
    assert_receive {:notifier, %{"username" => "WarnBot"}, _}, 1_000
    refute_receive {:notifier, %{"username" => "ErrorBot"}, _}, 100

    # 3. :warn -> :error: "debug", "warn", and "error" should all notify
    event3 = %Event{
      alert: alert,
      status: :error,
      prev_status: :warn,
      fail_duration: 5,
      last_update: NaiveDateTime.utc_now(),
      metadata: %{"message" => "oom"}
    }

    Event.notify(event3)
    assert_receive {:notifier, %{"username" => "TestBot"}, _}, 1_000
    assert_receive {:notifier, %{"username" => "WarnBot"}, _}, 1_000
    assert_receive {:notifier, %{"username" => "ErrorBot"}, _}, 1_000

    # 4. :error -> :error: only "debug" should notify
    event4 = %Event{
      alert: alert,
      status: :error,
      prev_status: :error,
      fail_duration: 10,
      last_update: NaiveDateTime.utc_now(),
      metadata: %{"message" => "oom"}
    }

    Event.notify(event4)
    assert_receive {:notifier, %{"username" => "TestBot"}, _}, 1_000
    refute_receive {:notifier, %{"username" => "WarnBot"}, _}, 100
    refute_receive {:notifier, %{"username" => "ErrorBot"}, _}, 100

    # 5. :error -> :ok: all should notify
    event5 = %Event{
      alert: alert,
      status: :ok,
      prev_status: :error,
      fail_duration: 15,
      last_update: NaiveDateTime.utc_now(),
      metadata: %{"message" => "recovered"}
    }

    Event.notify(event5)
    assert_receive {:notifier, %{"username" => "TestBot"}, _}, 1_000
    assert_receive {:notifier, %{"username" => "WarnBot"}, _}, 1_000
    assert_receive {:notifier, %{"username" => "ErrorBot"}, _}, 1_000
  end

  test "Event.Notification raises on invalid log_level", _context do
    invalid_notifier_alert =
      Alert.make!(%{
        id: "alert-invalid",
        name: "Invalid",
        host: %{id: "h", name: "h", module: Hemdal.Host.Local},
        command: %{name: "c", type: "line", command: "echo"},
        notifiers: [
          %{
            module: Hemdal.Notifier.Mock,
            token: "TOKEN",
            username: "InvalidBot",
            log_level: "invalid_level",
            metadata: %{pid: self()}
          }
        ]
      })

    event = %Event{
      alert: invalid_notifier_alert,
      status: :ok,
      prev_status: :warn,
      fail_duration: 0,
      last_update: NaiveDateTime.utc_now(),
      metadata: %{}
    }

    assert_raise RuntimeError, ~r/ERROR! The value for level/, fn ->
      Notification.process_event(event, %{})
    end
  end

  test "Event.Log process_event directly across levels and statuses", %{alert: alert} do
    statuses = [
      {:disabled, :ok},
      {:ok, :ok},
      {:ok, :warn},
      {:ok, :error},
      {:warn, :ok},
      {:warn, :warn},
      {:error, :warn},
      {:error, :error},
      {:unknown_status, nil}
    ]

    for {status, prev} <- statuses do
      event = %Event{
        alert: alert,
        status: status,
        prev_status: prev,
        fail_duration: 10,
        last_update: NaiveDateTime.utc_now(),
        metadata: %{}
      }

      assert {:noreply, [], _} = Log.handle_events([event], self(), %{log_level: "debug"})
      assert {:noreply, [], _} = Log.handle_events([event], self(), %{log_level: "warn"})
      assert {:noreply, [], _} = Log.handle_events([event], self(), %{log_level: "error"})
    end
  end

  test "Event producer init and handle_demand" do
    assert {:producer, [], dispatcher: GenStage.BroadcastDispatcher} = Event.init([])
    assert {:noreply, ["event1"], ["event2"]} = Event.handle_demand(1, ["event1", "event2"])
  end
end
