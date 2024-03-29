defmodule Hemdal.Host.Local do
  @moduledoc """
  Implement the host access for the local running commands.
  It is intended to run commands locally where the system is.

  It's not recommended when we are going to put the running
  system inside of a container because it's very limited.
  """
  use Hemdal.Host

  @typedoc """
  Because of an error in Construct, we need to provide the type
  `t()` for each default value if that's a module or an atom different
  from `nil`, `true`, `false`:

  https://github.com/ExpressApp/construct/issues/38

  Remove this type when the issue is closed and the code is in use by
  this library.
  """
  @type t() :: module()

  @impl Hemdal.Host
  @doc """
  Run locally a command. It's using `System.shell/2` for achieving that.
  """
  def exec(_opts, command) do
    {output, errorlevel} = System.shell(to_string(command), [])
    {:ok, errorlevel, output}
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
