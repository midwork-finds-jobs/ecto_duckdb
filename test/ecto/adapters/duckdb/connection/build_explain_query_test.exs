defmodule Ecto.Adapters.DuckDB.Connection.BuildExplainQueryTest do
  use ExUnit.Case, async: true

  alias Ecto.Adapters.DuckDB.Connection

  test "build_explain_query" do
    assert Connection.build_explain_query("SELECT 1", :query_plan) ==
             "EXPLAIN QUERY PLAN SELECT 1"

    assert Connection.build_explain_query("SELECT 1", :instructions) ==
             "EXPLAIN SELECT 1"
  end
end
