defmodule Ecto.Adapters.DuckDB.DeleteTest do
  use ExUnit.Case, async: true

  import Ecto.Adapters.DuckDB.TestHelpers

  test "delete" do
    query = delete(nil, "schema", [x: 1, y: 2], [])
    assert query == ~s{DELETE FROM "schema" WHERE "x" = ? AND "y" = ?}
  end
end
