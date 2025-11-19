defmodule Ecto.Adapters.DuckDBex.DataType do
  @moduledoc false

  @spec column_type(atom(), Keyword.t()) :: String.t()
  def column_type(:id, _opts), do: "INTEGER"
  def column_type(:serial, _opts), do: "INTEGER"
  def column_type(:bigserial, _opts), do: "BIGINT"
  def column_type(:boolean, _opts), do: "BOOLEAN"
  def column_type(:integer, _opts), do: "INTEGER"
  def column_type(:bigint, _opts), do: "BIGINT"
  def column_type(:string, _opts), do: "VARCHAR"
  def column_type(:float, _opts), do: "DOUBLE"
  def column_type(:binary, _opts), do: "BLOB"
  def column_type(:date, _opts), do: "DATE"
  def column_type(:utc_datetime, _opts), do: "TIMESTAMP"
  def column_type(:utc_datetime_usec, _opts), do: "TIMESTAMP"
  def column_type(:naive_datetime, _opts), do: "TIMESTAMP"
  def column_type(:naive_datetime_usec, _opts), do: "TIMESTAMP"
  def column_type(:time, _opts), do: "TIME"
  def column_type(:time_usec, _opts), do: "TIME"
  def column_type(:timestamp, _opts), do: "TIMESTAMP"
  def column_type(:decimal, nil), do: "DECIMAL"

  def column_type(:decimal, opts) do
    precision = Keyword.get(opts, :precision)
    scale = Keyword.get(opts, :scale, 0)

    if precision do
      "DECIMAL(#{precision},#{scale})"
    else
      "DECIMAL"
    end
  end

  def column_type(:array, _opts) do
    case Application.get_env(:ecto_duckdbex, :array_type, :string) do
      :string -> "VARCHAR"
      :binary -> "BLOB"
    end
  end

  def column_type({:array, _}, _opts) do
    case Application.get_env(:ecto_duckdbex, :array_type, :string) do
      :string -> "VARCHAR"
      :binary -> "BLOB"
    end
  end

  def column_type(:binary_id, _opts) do
    case Application.get_env(:ecto_duckdbex, :binary_id_type, :string) do
      :string -> "VARCHAR"
      :binary -> "BLOB"
    end
  end

  def column_type(:map, _opts) do
    case Application.get_env(:ecto_duckdbex, :map_type, :string) do
      :string -> "VARCHAR"
      :binary -> "BLOB"
    end
  end

  def column_type({:map, _}, _opts) do
    case Application.get_env(:ecto_duckdbex, :map_type, :string) do
      :string -> "VARCHAR"
      :binary -> "BLOB"
    end
  end

  def column_type(:uuid, _opts) do
    case Application.get_env(:ecto_duckdbex, :uuid_type, :string) do
      :string -> "VARCHAR"
      :binary -> "BLOB"
    end
  end

  def column_type(type, _) when is_atom(type) do
    type
    |> Atom.to_string()
    |> String.upcase()
  end

  def column_type(type, _) do
    raise ArgumentError,
          "unsupported type `#{inspect(type)}`. The type can either be an atom, a string " <>
            "or a tuple of the form `{:map, t}` or `{:array, t}` where `t` itself follows the same conditions."
  end
end
