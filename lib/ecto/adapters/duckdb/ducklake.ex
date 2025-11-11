defmodule Ecto.Adapters.DuckDB.DuckLake do
  @moduledoc """
  DuckLake-specific operations for the DuckDB Ecto adapter.

  DuckLake is an open table format that stores metadata in a DuckDB file
  and data in Parquet files. It provides:

  - ACID transactions
  - Schema evolution
  - Time travel (snapshot-based versioning)
  - Open Parquet storage for interoperability

  ## Usage

  Enable DuckLake mode in your repository configuration:

      config :myapp, MyApp.Repo,
        adapter: Ecto.Adapters.DuckDB,
        database: "myapp.ducklake",
        ducklake: true,
        pool_size: 1

  Or let it auto-detect based on `.ducklake` extension:

      config :myapp, MyApp.Repo,
        adapter: Ecto.Adapters.DuckDB,
        database: "myapp.ducklake",  # Auto-enables DuckLake
        pool_size: 1

  ## Functions

  This module provides functions for:
  - Snapshot management and history
  - Table information and statistics
  - File maintenance and cleanup
  """

  @doc """
  List all snapshots for the DuckLake database.

  Returns a list of maps containing snapshot information including:
  - `snapshot_id` - Numeric identifier for the snapshot
  - `snapshot_time` - Timestamp when snapshot was created
  - `schema_version` - Schema version at this snapshot
  - `commit_message` - Optional commit message
  - `commit_extra_info` - Additional metadata

  ## Examples

      iex> DuckDB.DuckLake.snapshots(MyApp.Repo)
      [
        %{
          snapshot_id: 0,
          snapshot_time: ~U[2025-10-28 10:00:00Z],
          schema_version: 1,
          commit_message: nil,
          commit_extra_info: nil
        },
        %{
          snapshot_id: 1,
          snapshot_time: ~U[2025-10-28 10:05:00Z],
          schema_version: 1,
          commit_message: nil,
          commit_extra_info: nil
        }
      ]
  """
  def snapshots(repo, opts \\ []) do
    catalog_name = get_catalog_name(repo)

    sql =
      "SELECT snapshot_id, snapshot_time, schema_version, commit_message, commit_extra_info
           FROM ducklake_snapshots('#{catalog_name}')"

    case repo.query(sql, [], opts) do
      {:ok, %{rows: rows, columns: columns}} ->
        Enum.map(rows, fn row ->
          columns
          |> Enum.zip(row)
          |> Map.new()
        end)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get detailed information about a specific table.

  Returns statistics including file counts, sizes, row counts, and delete metrics.

  ## Examples

      iex> DuckDB.DuckLake.table_info(MyApp.Repo, "posts")
      {:ok, %{
        table_name: "posts",
        file_count: 3,
        total_size_bytes: 4096,
        row_count: 150,
        delete_count: 10
      }}
  """
  def table_info(repo, table_name, opts \\ []) do
    catalog_name = get_catalog_name(repo)

    sql = "SELECT * FROM ducklake_table_info('#{catalog_name}', '#{table_name}')"

    case repo.query(sql, [], opts) do
      {:ok, %{rows: [row], columns: columns}} ->
        info = columns |> Enum.zip(row) |> Map.new()
        {:ok, info}

      {:ok, %{rows: []}} ->
        {:error, :table_not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Expire old snapshots to save space.

  Removes snapshots older than the specified retention count.

  ## Options

  - `:retain_last` - Number of recent snapshots to keep (default: 10)

  ## Examples

      iex> DuckDB.DuckLake.expire_snapshots(MyApp.Repo, retain_last: 5)
      :ok
  """
  def expire_snapshots(repo, opts \\ []) do
    catalog_name = get_catalog_name(repo)
    retain_last = Keyword.get(opts, :retain_last, 10)

    sql = "CALL ducklake_expire_snapshots('#{catalog_name}', #{retain_last})"

    case repo.query(sql, [], opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Clean up old data files that are no longer referenced by any snapshot.

  This is safe to run and will only remove files that are orphaned.

  ## Examples

      iex> DuckDB.DuckLake.cleanup_old_files(MyApp.Repo)
      :ok
  """
  def cleanup_old_files(repo, opts \\ []) do
    catalog_name = get_catalog_name(repo)

    sql = "CALL ducklake_cleanup_old_files('#{catalog_name}')"

    case repo.query(sql, [], opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Merge adjacent small Parquet files to improve query performance.

  This can help reduce the overhead of many small files.

  ## Examples

      iex> DuckDB.DuckLake.merge_adjacent_files(MyApp.Repo, "posts")
      :ok
  """
  def merge_adjacent_files(repo, table_name, opts \\ []) do
    catalog_name = get_catalog_name(repo)

    sql = "CALL ducklake_merge_adjacent_files('#{catalog_name}', '#{table_name}')"

    case repo.query(sql, [], opts) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  # Private functions

  defp get_catalog_name(repo) do
    config = repo.config()
    database = config[:database]

    database
    |> Path.basename()
    |> String.replace_suffix(".ducklake", "")
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
  end
end
