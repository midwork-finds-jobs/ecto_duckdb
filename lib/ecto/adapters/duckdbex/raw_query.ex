defmodule Ecto.Adapters.DuckDBex.RawQuery do
  @moduledoc """
  Provides raw query execution for DuckDBex that bypasses prepared statements.

  This allows executing multi-statement queries that are not supported by
  the standard DBConnection protocol's prepared statement system.

  ## Usage

  Add to your Repo module:

      defmodule MyApp.Repo do
        use Ecto.Repo,
          otp_app: :my_app,
          adapter: Ecto.Adapters.DuckDBex

        # Import raw query support
        use Ecto.Adapters.DuckDBex.RawQuery
      end

  Then use it in your code:

      MyApp.Repo.exec!(\"\"\"
        INSTALL httpfs;
        LOAD httpfs;
        SELECT * FROM read_parquet('s3://bucket/file.parquet');
      \"\"\")
  """

  @doc """
  Execute a raw SQL query that may contain multiple statements.

  This bypasses the prepared statement system and executes the query directly
  using the low-level Duckdbex NIF. This is useful for:

  - Multi-statement queries (separated by semicolons)
  - DDL statements like INSTALL/LOAD extensions
  - Queries with CTEs or complex SQL that may not work with prepared statements

  Returns a `Duckdbex.Result` struct.

  ## Examples

      # Single statement
      Repo.exec!("SELECT 1")

      # Multiple statements
      Repo.exec!(\"\"\"
        INSTALL httpfs;
        LOAD httpfs;
      \"\"\")

      # Complex query with CTE
      Repo.exec!(\"\"\"
        WITH data AS (SELECT * FROM table1)
        SELECT * FROM data;
      \"\"\")
  """
  defmacro __using__(_opts) do
    quote do
      def exec!(sql) when is_binary(sql) do
        Ecto.Adapters.DuckDBex.RawQuery.execute_raw!(__MODULE__, sql)
      end
    end
  end

  defmodule RawQuery do
    @moduledoc false
    defstruct [:sql]
  end

  @doc false
  def execute_raw!(repo, sql) when is_binary(sql) do
    alias Ecto.Adapters.DuckDBex.RawQuery.RawQuery

    adapter_meta = Ecto.Repo.Registry.lookup(repo)

    # Execute raw query through DBConnection.run to access the connection state
    DBConnection.run(adapter_meta.pid, fn conn_pid ->
      # Get the connection state from the protocol
      result = DBConnection.execute(conn_pid, %RawQuery{sql: sql}, [], [])

      case result do
        {:ok, _query, result} -> result
        {:error, error} -> raise error
      end
    end)
  end
end

defimpl DBConnection.Query, for: Ecto.Adapters.DuckDBex.RawQuery.RawQuery do
  def parse(query, _opts), do: query
  def describe(query, _opts), do: query
  def encode(_query, params, _opts), do: params
  def decode(_query, result, _opts), do: result
end
