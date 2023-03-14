defmodule Hemdal.Config.Options do
  @moduledoc """
  Define the options (`Keyword`) implementation for `Construct`. This way we
  can use the `Hemdal.Config.Options` everywhere the `options` entry is
  needed.
  """
  @behaviour Construct.Type

  @typedoc "Options is `Keyword.t()` or `map()`."
  @type t() :: Keyword.t() | map()

  @spec cast(term) :: {:ok, t()} | {:error, term} | :error
  @doc false
  def cast([{_key, _value} | _] = keyword), do: {:ok, keyword}
  def cast(%{} = map), do: {:ok, map}
end
