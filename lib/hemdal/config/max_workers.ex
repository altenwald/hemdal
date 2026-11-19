defmodule Hemdal.Config.MaxWorkers do
  @moduledoc """
  Defines the `max_workers` config type. Supports non-negative integers and `:infinity`.
  """
  @behaviour Hemdal.Config.Schema

  @typedoc "Max workers is `:infinity` or `non_neg_integer()`."
  @type t() :: :infinity | non_neg_integer()

  @spec cast(term) :: {:ok, t()} | {:error, term} | :error
  @doc false
  def cast(:infinity), do: {:ok, :infinity}
  def cast("infinity"), do: {:ok, :infinity}
  def cast(n) when is_integer(n) and n >= 0, do: {:ok, n}
  def cast(_), do: :error
end
