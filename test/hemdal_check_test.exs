defmodule HemdalCheckTest do
  use ExUnit.Case
  require Logger

  alias Hemdal.Check

  test "get correct alert check" do
    alert = Hemdal.Config.get_alert_by_id!("aea48656-be08-4576-a2d0-2723458faefd")
    {:ok, pid} = Check.update_alert(alert)
    assert pid == Check.get_pid(alert.id)

    ## FIXME: start of the supervisor isn't fast enough and request is missed?!?
    Process.sleep(500)

    status = Check.get_status(alert.id)
    assert %{"status" => :ok, "result" => %{"message" => "valid one!"}} = status
    Process.sleep(1_000)
    status = Check.get_status(alert.id)
    assert %{"status" => :ok, "result" => %{"message" => "valid one!"}} = status

    Hemdal.Event.Log.stop()
    Check.stop(pid)
  end

  test "get failing and broken alert check but with a working script" do
    alert = Hemdal.Config.get_alert_by_id!("6b6d247c-48c3-4a8c-9b4f-773f178ddc0f")
    {:ok, _pid} = Check.update_alert(alert)

    ## FIXME: start of the supervisor isn't fast enough and request is missed?!?
    Process.sleep(500)

    status = Check.get_status(alert.id)
    assert %{"status" => :warn, "result" => %{"message" => "invalid one!"}} = status
    Process.sleep(1_000)
    status = Check.get_status(alert.id)
    assert %{"status" => :error, "result" => %{"message" => "invalid one!"}} = status

    Hemdal.Event.Log.stop()
    Check.stop(alert.id)
  end
end
