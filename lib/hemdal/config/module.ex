defmodule Hemdal.Config.Module do
  @moduledoc """
  Defines the type for module in use for the `Hemdal.Config.Notifier` and
  `Hemdal.Host` implementations to define which modules will be in use for
  each case.
  """
  @behaviour Construct.Type

  @typedoc "Module is `module()`."
  @type t() :: module()

  @spec cast(term) :: {:ok, term} | {:error, term} | :error
  @doc false
  def cast(value) when is_binary(value) do
    {:ok, String.to_existing_atom("Elixir.#{value}")}
  end

  def cast(value) when is_atom(value), do: {:ok, value}
end
