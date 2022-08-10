defmodule Hemdal.Config.Type.Module do
  @behaviour Construct.Type

  def cast(mod) when is_binary(mod) do
    try do
      {:ok, String.to_existing_atom(mod)}
    rescue
      _error -> :error
    end
  end

  def cast(_), do: :error
end
