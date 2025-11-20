defmodule Duckdbex.ProtocolTest do
  use ExUnit.Case, async: false

  alias Duckdbex.Protocol

  describe "post-connection initialization" do
    test "connects without any special options" do
      opts = [database: ":memory:"]
      assert {:ok, state} = Protocol.connect(opts)
      assert state.conn
      assert state.db
      assert state.cache == %{}
      Protocol.disconnect(nil, state)
    end

    test "connects with simple attach" do
      # Create two separate databases
      db1_path = "test_db1_#{:rand.uniform(10000)}.duckdb"
      db2_path = "test_db2_#{:rand.uniform(10000)}.duckdb"

      try do
        # Create and populate first database
        {:ok, db1} = Duckdbex.open(db1_path)
        {:ok, conn1} = Duckdbex.connection(db1)

        {:ok, result_ref} =
          Duckdbex.query(conn1, "CREATE TABLE test_table (id INTEGER, name VARCHAR)")

        Duckdbex.release(result_ref)
        {:ok, result_ref} = Duckdbex.query(conn1, "INSERT INTO test_table VALUES (1, 'Alice')")
        Duckdbex.release(result_ref)
        Duckdbex.release(conn1)
        Duckdbex.release(db1)

        # Connect to second database and attach first
        opts = [
          database: db2_path,
          attach: [
            {db1_path, [as: :db1]}
          ]
        ]

        assert {:ok, state} = Protocol.connect(opts)

        # Verify we can query the attached database
        {:ok, conn} = DBConnection.start_link(Protocol, opts)

        {:ok, _, result} =
          DBConnection.prepare_execute(
            conn,
            %Duckdbex.Query{query: "SELECT * FROM db1.test_table"},
            []
          )

        assert length(result.rows) == 1
        assert hd(result.rows) == [1, "Alice"]

        Process.exit(conn, :normal)
        Protocol.disconnect(nil, state)
      after
        File.rm(db1_path)
        File.rm(db2_path)
      end
    end

    test "connects with USE option" do
      db1_path = "test_main_#{:rand.uniform(10000)}.duckdb"
      db2_path = "test_attached_#{:rand.uniform(10000)}.duckdb"

      try do
        # Create and populate attached database
        {:ok, db1} = Duckdbex.open(db2_path)
        {:ok, conn1} = Duckdbex.connection(db1)
        {:ok, result_ref} = Duckdbex.query(conn1, "CREATE TABLE users (id INTEGER, name VARCHAR)")
        Duckdbex.release(result_ref)
        {:ok, result_ref} = Duckdbex.query(conn1, "INSERT INTO users VALUES (1, 'Bob')")
        Duckdbex.release(result_ref)
        Duckdbex.release(conn1)
        Duckdbex.release(db1)

        # Connect with attach and use
        opts = [
          database: db1_path,
          attach: [
            {db2_path, [as: :attached_db]}
          ],
          use: :attached_db
        ]

        {:ok, conn} = DBConnection.start_link(Protocol, opts)

        # Query should work without database prefix because of USE
        {:ok, _, result} =
          DBConnection.prepare_execute(conn, %Duckdbex.Query{query: "SELECT * FROM users"}, [])

        assert length(result.rows) == 1
        assert hd(result.rows) == [1, "Bob"]

        Process.exit(conn, :normal)
      after
        File.rm(db1_path)
        File.rm(db2_path)
      end
    end
  end
end
