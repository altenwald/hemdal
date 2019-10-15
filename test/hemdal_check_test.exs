defmodule HemdalCheckTest do
  use ExUnit.Case
  require Logger

  alias Hemdal.{Repo, Check, Alert}

  def get_path_for(uri) do
    Path.join([__DIR__, uri])
  end
  
  def start_daemon(port) do
    :ok = :ssh.start()
    opts = [
      system_dir: String.to_charlist(get_path_for("daemon1")),
      user_dir: String.to_charlist(get_path_for("user")),
    ]
    {:ok, sshd} = :ssh.daemon(port, opts)
    {:ok, [{:port, ^port}|_]} = :ssh.daemon_info(sshd)
    {:ok, sshd}
  end
  
  def stop_daemon(sshd) do
    :ok = :ssh.stop_listener(sshd)
    :ok = :ssh.stop_daemon(sshd)
    :ok = :ssh.stop()
    :ok
  end
  
  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    # Setting the shared mode must be done only after checkout
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
  end

  test "get correct alert check" do
    alert = Alert.get_by_id!("aea48656-be08-4576-a2d0-2723458faefd")
    {:ok, sshd} = start_daemon(alert.host.port)
    # Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), Hemdal.EventLogger)
    {:ok, pid} = Check.update_alert(alert)
    assert pid == Check.get_pid(alert.id) 

    ## FIXME: start of the supervisor isn't fast enough and request is missed?!?
    Process.sleep(500)

    status = Check.get_status(alert.id)
    %{"status" => :ok, "result" => %{"description" => "valid one!"}} = status
    Process.sleep 1_000
    status = Check.get_status(alert.id)
    %{"status" => :ok, "result" => %{"description" => "valid one!"}} = status

    Hemdal.EventLogger.stop()
    Check.stop(pid)
    :ok = stop_daemon(sshd)
  end

  test "get failing and broken alert check but with a working script" do
    alert = Alert.get_by_id!("6b6d247c-48c3-4a8c-9b4f-773f178ddc0f")
    {:ok, sshd} = start_daemon(alert.host.port)
    # Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), Hemdal.EventLogger)
    {:ok, _pid} = Check.update_alert(alert)

    ## FIXME: start of the supervisor isn't fast enough and request is missed?!?
    Process.sleep(500)

    status = Check.get_status(alert.id)
    %{"status" => :warn, "result" => %{"description" => "invalid one!"}} = status
    Process.sleep 1_000
    status = Check.get_status(alert.id)
    %{"status" => :error, "result" => %{"description" => "invalid one!"}} = status

    Hemdal.EventLogger.stop()
    Check.stop(alert.id)
    :ok = stop_daemon(sshd)
  end
end
