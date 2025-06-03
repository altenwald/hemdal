defmodule Hemdal.Host.Local do
  @moduledoc """
  Implement the host access for the local running commands.
  It is intended to run commands locally where the system is.

  It's not recommended when we are going to put the running
  system inside of a container because it's very limited.
  """
  use Hemdal.Host

  @default_idle_timeout :timer.minutes(1)

  @impl Hemdal.Host
  @doc """
  Run locally a command. It's using `System.shell/2` for achieving that.
  """
  def exec(_opts, command) do
    {output, errorlevel} = System.shell(to_string(command), [])
    {:ok, errorlevel, output}
  end

  @impl Hemdal.Host
  def exec_interactive(_opts, command, caller, opts) when is_pid(caller) do
    port = Port.open({:spawn, command}, [:binary])
    send(caller, {:start, self()})
    output = if(opts[:output], do: "")
    opts = [{:echo, false} | opts]
    get_and_send_all(port, caller, output, opts)
  end

  @impl Hemdal.Host
  def shell(_opts, caller, opts) when is_pid(caller) do
    port = Port.open({:spawn, opts[:command]}, [:binary])
    send(caller, {:start, self()})
    output = if(opts[:output], do: "")
    opts = [{:echo, true} | opts]
    get_and_send_all(port, caller, output, opts)
  end

  defp get_and_send_all(port, caller, output, opts) do
    receive do
      {:data, data} ->
        send(port, {self(), {:command, data}})

        if opts[:echo] do
          send(caller, {:continue, data})
          get_and_send_all(port, caller, output <> data, opts)
        else
          get_and_send_all(port, caller, output, opts)
        end

      {^port, {:data, data}} ->
        send(caller, {:continue, data})
        output = if(output, do: output <> data)
        get_and_send_all(port, caller, output, opts)

      :close ->
        send(port, {self(), :close})
        get_and_send_all(port, caller, output, opts)

      {^port, :closed} ->
        send(caller, :closed)
        {:ok, 0, output}
    after
      opts[:timeout] || @default_idle_timeout ->
        Port.close(port)
        send(caller, :closed)
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
