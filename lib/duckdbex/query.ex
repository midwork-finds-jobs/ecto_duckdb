defmodule Duckdbex.Query do
  @moduledoc """
  Query struct returned after successfully preparing query.
  """

  @type t :: %__MODULE__{
          query: String.t(),
          stmt: String.t() | nil,
          columns: list(),
          rows: list()
        }

  defstruct [:query, :stmt, :columns, :rows]

  defimpl DBConnection.Query do
    def decode(_query, %Duckdbex.Result{} = result, _opts) do
      result
    end

    def describe(query, _opts), do: query

    def encode(_query, params, _opts), do: params

    def parse(query, _opts), do: query
  end

  defimpl String.Chars do
    def to_string(%@for{} = query), do: query.query
  end
end
