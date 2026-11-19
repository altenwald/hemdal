defmodule Hemdal.Config.Options do
  @moduledoc """
  Defines the options (`Keyword.t()` or `map()`) config type.
  """
  @behaviour Hemdal.Config.Schema

  @typedoc "Options is `Keyword.t()` or `map()`."
  @type t() :: Keyword.t() | map()

  @spec cast(term) :: {:ok, t()} | {:error, term} | :error
  @doc false
  def cast([]), do: {:ok, []}
  def cast([{_key, _value} | _] = keyword), do: {:ok, keyword}
  def cast(%{} = map), do: {:ok, map}
  def cast(_), do: :error
end
