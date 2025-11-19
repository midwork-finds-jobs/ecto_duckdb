defmodule Duckdbex.Protocol do
  @moduledoc false

  use DBConnection

  alias Duckdbex.Result

  require Logger

  ## ------------------------------------------------------------------
  ## gen_server Function Definitions
  ## ------------------------------------------------------------------

  @impl true
  def connect(opts) do
    Logger.debug("Initiating connect: #{inspect(opts)}")

    database = Keyword.get(opts, :database, ":memory:")

    # Convert :memory to ":memory:" string for duckdbex
    database = if database == :memory, do: nil, else: database

    # Open database
    {:ok, db} = if database do
      Duckdbex.open(database)
    else
      Duckdbex.open()
    end

    # Create connection
    {:ok, conn} = Duckdbex.connection(db)

    # Store both db and conn references
    state = %{db: db, conn: conn, cache: %{}}

    {:ok, state}
  end

  @impl true
  def checkout(state), do: {:ok, state}

  @impl true
  def disconnect(_err, state) do
    # Release connection and database
    Duckdbex.release(state.conn)
    Duckdbex.release(state.db)
    :ok
  end

  @impl true
  def handle_begin(_opts, %{} = state) do
    case execute_simple(state.conn, "BEGIN TRANSACTION") do
      {:ok, result} ->
        {:ok, result, state}

      {:error, err} ->
        {:disconnect, err, state}
    end
  end

  @impl true
  def handle_close(query, _opts, %{cache: cache} = state) do
    # Remove from cache if it exists
    new_cache = Map.delete(cache, query.stmt)
    {:ok, %Result{}, %{state | cache: new_cache}}
  end

  @impl true
  def handle_commit(_opts, %{} = state) do
    case execute_simple(state.conn, "COMMIT") do
      {:ok, result} -> {:ok, result, state}
      {:error, err} -> {:disconnect, err, state}
    end
  end

  @impl true
  def handle_deallocate(_query, _cursor, _opts, %{} = state) do
    # Duckdbex handles statement deallocation automatically
    {:ok, %Result{}, state}
  end

  @impl true
  def handle_declare(query, params, _opts, %{cache: cache} = state) do
    # For cursors, we execute and return a cursor identifier
    case execute_query(state.conn, query.stmt, params, cache) do
      {:ok, result} ->
        cursor = make_ref()
        {:ok, query, %{result | cursor: cursor}, state}

      {:error, err} ->
        {:error, err, state}
    end
  end

  @impl true
  def handle_execute(query, params, _opts, %{cache: cache} = state) do
    Logger.debug("Executing query with stmt: #{inspect(query.stmt)}, params: #{inspect(params)}")

    case execute_query(state.conn, query.stmt, params, cache) do
      {:ok, result} ->
        Logger.debug("Execute successful")
        {:ok, query, result, state}

      {:error, err} ->
        Logger.error("Execute error: #{inspect(err)}")
        {:error, err, state}
    end
  end

  @impl true
  def handle_fetch(_query, _cursor, _opts, %{} = state) do
    # Since we fetch all results at once, just return empty result
    {:halt, %Result{rows: [], columns: []}, state}
  end

  @impl true
  def handle_prepare(query, _opts, %{cache: cache} = state) do
    Logger.debug("Preparing query: #{inspect(query.query)}")

    case Duckdbex.prepare_statement(state.conn, query.query) do
      {:ok, stmt_ref} ->
        # Use the reference itself as the cache key
        new_cache = Map.put(cache, stmt_ref, stmt_ref)
        Logger.debug("Query prepared with stmt_ref: #{inspect(stmt_ref)}")
        {:ok, %{query | stmt: stmt_ref}, %{state | cache: new_cache}}

      {:error, err} ->
        Logger.error("Prepare error: #{inspect(err)}")
        error = %Duckdbex.Error{message: "#{inspect(err)}"}
        {:error, error, state}
    end
  end

  @impl true
  def handle_rollback(_opts, %{} = state) do
    case execute_simple(state.conn, "ROLLBACK") do
      {:ok, result} ->
        {:ok, result, state}

      {:error, err} ->
        {:disconnect, err, state}
    end
  end

  @impl true
  def handle_status(_opts, %{} = state) do
    {:idle, state}
  end

  @impl true
  def ping(state), do: {:ok, state}

  # Private helper functions

  defp execute_simple(conn, sql) do
    case Duckdbex.query(conn, sql) do
      {:ok, result_ref} ->
        rows = Duckdbex.fetch_all(result_ref)
        Duckdbex.release(result_ref)
        {:ok, %Result{rows: rows || [], columns: []}}

      {:error, _} = error ->
        error
    end
  catch
    kind, reason ->
      {:error, %Duckdbex.Error{message: "#{kind}: #{inspect(reason)}"}}
  end

  defp execute_query(_conn, stmt_ref, params, _cache) when is_reference(stmt_ref) do
    result = if params == [] do
      Duckdbex.execute_statement(stmt_ref)
    else
      Duckdbex.execute_statement(stmt_ref, params)
    end

    case result do
      {:ok, result_ref} ->
        rows = Duckdbex.fetch_all(result_ref)
        columns = extract_columns(result_ref)
        Duckdbex.release(result_ref)
        {:ok, %Result{rows: rows || [], columns: columns, num_rows: length(rows || [])}}

      {:error, _} = error ->
        error
    end
  catch
    kind, reason ->
      {:error, %Duckdbex.Error{message: "#{kind}: #{inspect(reason)}"}}
  end

  defp extract_columns(_result_ref) do
    # Duckdbex doesn't provide easy column name extraction in current API
    # We'll return empty for now and rely on Ecto's schema information
    []
  end
end
