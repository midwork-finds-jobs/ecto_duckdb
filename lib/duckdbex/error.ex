defmodule Duckdbex.Error do
  @moduledoc """
  Error exception for DuckDB operations.
  """

  defexception [:message]

  @type t :: %__MODULE__{
          message: String.t()
        }
end
