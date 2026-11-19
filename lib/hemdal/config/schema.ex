defmodule Hemdal.Config.MakeError do
  @moduledoc """
  Raised by the `make!/2` functions of the configuration structures when the
  given parameters are not valid.
  """

  defexception [:reason, :params]

  @impl true
  def message(%{reason: reason}) do
    "invalid configuration: #{inspect(reason)}"
  end
end

defmodule Hemdal.Config.Schema do
  @moduledoc false

  @type field_type ::
          :string
          | :integer
          | :boolean
          | :map
          | {:array, field_type()}
          | module()

  @type field_spec :: {atom(), field_type(), keyword()}

  @callback cast(term()) :: {:ok, term()} | {:error, term()} | :error

  @doc """
  Builds the `mod` struct from `params` following the `fields` definition.
  Returns `{:ok, struct}` or `{:error, errors}` with the errors by field.
  """
  @spec make(module(), [field_spec()], map() | keyword(), keyword()) ::
          {:ok, struct()} | {:error, map()}
  def make(mod, fields, params, opts \\ [])

  def make(mod, fields, params, opts) when is_list(params) do
    if Keyword.keyword?(params) do
      make(mod, fields, Map.new(params), opts)
    else
      {:error, %{params: :invalid}}
    end
  end

  def make(mod, fields, %{} = params, opts) do
    {attrs, errors} =
      Enum.reduce(fields, {%{}, %{}}, fn field, acc -> put_field(field, params, opts, acc) end)

    if map_size(errors) == 0 do
      {:ok, struct!(mod, attrs)}
    else
      {:error, errors}
    end
  end

  def make(_mod, _fields, _params, _opts), do: {:error, %{params: :invalid}}

  @doc """
  Same as `make/4` but returns the struct or raises `Hemdal.Config.MakeError`.
  """
  @spec make!(module(), [field_spec()], map() | keyword(), keyword()) :: struct()
  def make!(mod, fields, params, opts \\ []) do
    case make(mod, fields, params, opts) do
      {:ok, struct} -> struct
      {:error, reason} -> raise Hemdal.Config.MakeError, reason: reason, params: params
    end
  end

  defp put_field({name, type, field_opts}, params, opts, {attrs, errors}) do
    result =
      case fetch_param(params, name) do
        {:ok, nil} -> default_or_missing(field_opts)
        {:ok, value} -> cast_field(type, value, opts)
        :error -> default_or_missing(field_opts)
      end

    case result do
      {:ok, value} -> {Map.put(attrs, name, value), errors}
      {:error, reason} -> {attrs, Map.put(errors, name, reason)}
    end
  end

  defp default_or_missing(field_opts) do
    case Keyword.fetch(field_opts, :default) do
      {:ok, default} -> {:ok, default}
      :error -> {:error, :missing}
    end
  end

  defp cast_field(type, value, opts) do
    case cast_value(type, value, opts) do
      {:ok, _} = ok -> ok
      {:error, _} = error -> error
      :error -> {:error, :invalid}
    end
  end

  defp fetch_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, _} = ok -> ok
      :error -> Map.fetch(params, Atom.to_string(key))
    end
  end

  defp cast_value(:string, v, _opts) when is_binary(v), do: {:ok, v}
  defp cast_value(:string, _v, _opts), do: :error

  defp cast_value(:integer, v, _opts) when is_integer(v), do: {:ok, v}

  defp cast_value(:integer, v, _opts) when is_binary(v) do
    case Integer.parse(v) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp cast_value(:integer, _v, _opts), do: :error

  defp cast_value(:boolean, v, _opts) when is_boolean(v), do: {:ok, v}
  defp cast_value(:boolean, "true", _opts), do: {:ok, true}
  defp cast_value(:boolean, "false", _opts), do: {:ok, false}
  defp cast_value(:boolean, _v, _opts), do: :error

  defp cast_value(:map, %{} = v, _opts), do: {:ok, v}
  defp cast_value(:map, _v, _opts), do: :error

  defp cast_value({:array, inner}, list, opts) when is_list(list) do
    Enum.reduce_while(list, {:ok, []}, fn elem, {:ok, acc} ->
      case cast_value(inner, elem, opts) do
        {:ok, cast} -> {:cont, {:ok, [cast | acc]}}
        err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, rev} -> {:ok, Enum.reverse(rev)}
      err -> err
    end
  end

  defp cast_value({:array, _inner}, _v, _opts), do: :error

  defp cast_value(mod, value, opts) when is_atom(mod) do
    cond do
      Code.ensure_loaded?(mod) and function_exported?(mod, :cast, 1) -> mod.cast(value)
      is_struct(value, mod) -> {:ok, value}
      true -> mod.make(value, opts)
    end
  end
end
