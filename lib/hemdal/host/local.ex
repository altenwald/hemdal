defmodule Hemdal.Host.Local do
  use Hemdal.Host

  @impl Hemdal.Host
  def transaction(opts, f) do
    f.(opts)
  end

  @impl Hemdal.Host
  def exec(_opts, command) do
    {output, errorlevel} = System.shell(to_string(command), [])
    {:ok, errorlevel, output}
  end

  @impl Hemdal.Host
  def write_file(_opts, tmp_file, content) do
    File.write!(tmp_file, content)
  end

  @impl Hemdal.Host
  def delete(_opts, tmp_file) do
    File.rm!(tmp_file)
  end
end
