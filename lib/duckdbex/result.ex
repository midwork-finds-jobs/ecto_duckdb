defmodule Duckdbex.Result do
  @moduledoc """
  Result struct returned from database operations.
  """

  @type t :: %__MODULE__{
          columns: [String.t()],
          rows: [[term()]],
          num_rows: non_neg_integer(),
          cursor: reference() | nil
        }

  defstruct columns: [], rows: [], num_rows: 0, cursor: nil
end
