defmodule Ecto.Adapters.DuckDB.Connection.DDLTest do
  use ExUnit.Case, async: true

  alias Ecto.Migration.{Index, Table}
  alias Ecto.Adapters.DuckDB.Connection

  describe "execute_ddl/1 with indexes" do
    test "create index without prefix succeeds" do
      index = %Index{
        name: :posts_title_index,
        table: :posts,
        prefix: nil,
        columns: [:title],
        unique: false,
        concurrently: false,
        using: nil,
        include: [],
        nulls_distinct: nil,
        where: nil,
        comment: nil
      }

      result = Connection.execute_ddl({:create, index})
      assert is_list(result)
      assert [sql] = result
      assert IO.iodata_to_binary(sql) =~ ~r/CREATE INDEX "posts_title_index" ON "posts"/
    end

    test "create index with prefix raises ArgumentError for DuckLake" do
      index = %Index{
        name: :trains_service_number_index,
        table: :trains,
        prefix: "trains_db",
        columns: [:service_number],
        unique: false,
        concurrently: false,
        using: nil,
        include: [],
        nulls_distinct: nil,
        where: nil,
        comment: nil
      }

      assert_raise ArgumentError, ~r/DuckLake does not support indexes/, fn ->
        Connection.execute_ddl({:create, index})
      end
    end

    test "create index with prefix provides helpful error message" do
      index = %Index{
        name: :my_index,
        table: :my_table,
        prefix: "attached_db",
        columns: [:col1],
        unique: false,
        concurrently: false,
        using: nil,
        include: [],
        nulls_distinct: nil,
        where: nil,
        comment: nil
      }

      error =
        assert_raise ArgumentError, fn ->
          Connection.execute_ddl({:create, index})
        end

      message = Exception.message(error)
      assert message =~ "DuckLake"
      assert message =~ "attached_db"
      assert message =~ "my_index"
      assert message =~ "my_table"
      assert message =~ "columnar Parquet storage"
    end

    test "create_if_not_exists index with prefix raises ArgumentError" do
      index = %Index{
        name: :trains_station_index,
        table: :trains,
        prefix: "trains_db",
        columns: [:station_code],
        unique: false,
        concurrently: false,
        using: nil,
        include: [],
        nulls_distinct: nil,
        where: nil,
        comment: nil
      }

      assert_raise ArgumentError, ~r/DuckLake does not support indexes/, fn ->
        Connection.execute_ddl({:create_if_not_exists, index})
      end
    end

    test "create unique index with prefix raises ArgumentError" do
      index = %Index{
        name: :trains_unique_index,
        table: :trains,
        prefix: "trains_db",
        columns: [:id],
        unique: true,
        concurrently: false,
        using: nil,
        include: [],
        nulls_distinct: nil,
        where: nil,
        comment: nil
      }

      assert_raise ArgumentError, ~r/DuckLake does not support indexes/, fn ->
        Connection.execute_ddl({:create, index})
      end
    end

    test "drop index with prefix is allowed (for rollback compatibility)" do
      index = %Index{
        name: :trains_service_number_index,
        table: :trains,
        prefix: "trains_db",
        columns: [:service_number],
        unique: false,
        concurrently: false,
        using: nil,
        include: [],
        nulls_distinct: nil,
        where: nil,
        comment: nil
      }

      # Drop should work even with prefix (for rollback scenarios)
      result = Connection.execute_ddl({:drop, index})
      assert is_list(result)
    end
  end

  describe "execute_ddl/1 with tables" do
    test "create table with prefix is allowed" do
      table = %Table{
        name: :trains,
        prefix: "trains_db",
        comment: nil
      }

      # Tables with prefix should be allowed (unlike indexes)
      result = Connection.execute_ddl({:create, table, []})
      assert is_list(result)
    end
  end
end
