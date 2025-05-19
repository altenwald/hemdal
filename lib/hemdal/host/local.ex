defmodule Hemdal.Host.Local do
  @moduledoc """
  Implement the host access for the local running commands.
  It is intended to run commands locally where the system is.

  It's not recommended when we are going to put the running
  system inside of a container because it's very limited.
  """
  use Hemdal.Host

  @impl Hemdal.Host
  @doc """
  Run locally a command. It's using `System.shell/2` for achieving that.
  """
  def exec(_opts, command) do
    {output, errorlevel} = System.shell(to_string(command), [])
    {:ok, errorlevel, output}
  end

  @impl Hemdal.Host
  def exec_interactive(_opts, command, pid) do
    port = Port.open({:spawn, command}, [:binary])
    send(pid, {:start, self()})
    get_and_send_all(port, pid, "")
  end

  defp get_and_send_all(port, pid, output) do
    receive do
      {:data, data} ->
        send(port, {self(), {:command, data}})
        get_and_send_all(port, pid, output)

      :close ->
        send(port, {self(), :close})
        get_and_send_all(port, pid, output)

      {^port, {:data, data}} ->
        send(pid, {:continue, data})
        get_and_send_all(port, pid, output <> data)

      {^port, :closed} ->
        send(pid, :closed)
        {:ok, 0, output}
    after
      60_000 ->
        Port.close(port)
        send(pid, :closed)
        {:ok, 127, output}
    end
  end

  @impl Hemdal.Host
  @doc """
  Write a file locally, the file is intended to be located in a temporal
  location, if the file exists previously it will fail ensuring it's not
  overloading existent files.
  """
  def write_file(_opts, tmp_file, content) do
    File.write!(tmp_file, content, [:exclusive])
  end

  @impl Hemdal.Host
  @doc """
  Remove the temporal file.
  """
  def delete(_opts, tmp_file) do
    File.rm!(tmp_file)
  end
end
