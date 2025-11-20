defmodule Ecto.Adapters.DuckDB do
  @moduledoc """
  Adapter module for DuckDBex.

  It uses `Duckdbex` for communicating to the database.

  ## Options

  The adapter supports a superset of the options provided by the
  underlying `Duckdbex` driver.

  ### Provided options

    * `:database` - The path to the database. In memory is allowed. You can use
      `:memory` or `":memory:"` to designate that.
    * `:pool_size` - the size of the connection pool. **Must be set to 1** for DuckDB
      due to its single-writer limitation. Defaults to `1`.
    * `:temp_store` - Sets the storage used for temporary tables. Default is `:memory`.
      Allowed values are `:default`, `:file`, `:memory`.
    * `:cache_size` - Sets the cache size to be used for the connection. This is an odd
      setting as a positive value is the number of pages in memory to use and a negative
      value is the size in kilobytes to use. Default is `-64000`.
    * `:journal_mode` - Sets the journal mode. Defaults to `:wal`.
    * `:binary_id_type` - Defaults to `:string`. Determines how binary IDs are stored in
      the database and the type of `:binary_id` columns. See the
      [section on binary ID types](#module-binary-id-types) for more details.
    * `:uuid_type` - Defaults to `:string`. Determines the type of `:uuid` columns.
      Possible values and column types are the same as for
      [binary IDs](#module-binary-id-types).
    * `:map_type` - Defaults to `:string`. Determines the type of `:map` columns.
      Maps are serialized using JSON.
    * `:array_type` - Defaults to `:string`. Determines the type of `:array` columns.
      Arrays are serialized using JSON.
    * `:datetime_type` - Defaults to `:iso8601`. Determines how datetime fields are
      stored in the database. The allowed values are `:iso8601` and `:text_datetime`.
      `:iso8601` corresponds to a string of the form `YYYY-MM-DDThh:mm:ss` and
      `:text_datetime` corresponds to a string of the form `YYYY-MM-DD hh:mm:ss`

  For more information about DuckDB configuration, see [DuckDB documentation][1]

  [1]: https://duckdb.org/docs/

  ### DuckDB-specific Configuration

  DuckDB is an embedded analytical database optimized for OLAP workloads. Key considerations:

    * `:pool_size` - **Must be 1**. DuckDB uses MVCC (Multi-Version Concurrency Control)
      but only allows one writer at a time.
    * `:temp_store` - Uses `:memory` by default for better analytical performance.
    * `:cache_size` - Set to `-64000` (64MB) by default to optimize for analytical queries.

  ### Binary ID types

  The `:binary_id_type` configuration option allows configuring how `:binary_id` fields
  are stored in the database as well as the type of the column in which these IDs will
  be stored. The possible values are:

  * `:string` - IDs are stored as strings, and the type of the column is `TEXT`. This is
    the default.
  * `:binary` - IDs are stored in their raw binary form, and the type of the column is `BLOB`.

  The main differences between the two formats are as follows:
  * When stored as binary, UUIDs require much less space in the database. IDs stored as
    strings require 36 bytes each, while IDs stored as binary only require 16 bytes.
  * Because SQLite does not have a dedicated UUID type, most clients cannot represent
    UUIDs stored as binary in a human readable format. Therefore, IDs stored as strings
    may be easier to work with if manual manipulation is required.

  ## Limitations and caveats

  There are some limitations when using Ecto with DuckDB that one needs
  to be aware of. DuckDB is optimized for analytical (OLAP) workloads rather than
  transactional (OLTP) workloads.

  ### Pool Size Limitation

  **IMPORTANT**: DuckDB only allows one writer at a time. You must set `pool_size: 1`
  in your repository configuration.

      config :my_app, MyApp.Repo,
        adapter: Ecto.Adapters.DuckDB,
        database: "path/to/database.duckdb",
        pool_size: 1

  ### In memory robustness

  When using the adapter with the database set to `:memory` it is possible that
  a crash in a process performing a query in the Repo will cause the database
  to be destroyed. This makes the `:memory` function unsuitable when it is
  expected to survive potential process crashes (for example a crash in a
  Phoenix request)

  ### Async Sandbox testing

  The DuckDB adapter does not support async tests when used with
  `Ecto.Adapters.SQL.Sandbox`. This is due to DuckDB only allowing one write
  transaction at a time, which does not work with the Sandbox approach of wrapping
  each test in a transaction.

  ### Check constraints

  DuckDB supports check constraints on columns. You can add them in migrations:

      add :email, :string, check: %{name: "valid_email", expr: "email LIKE '%@%'"}

  ### Handling foreign key constraints in changesets

  Foreign key constraint handling in DuckDB follows standard SQL behavior. Changeset
  functions like `Ecto.Changeset.foreign_key_constraint/3` should work as expected.

  ### Schemaless queries

  Using schemaless Ecto queries works with DuckDB. The adapter properly handles type
  conversions for DuckDB's native types.

  ### Use Cases

  DuckDB is optimized for analytical (OLAP) workloads:

    * **Good fit**: Analytics, reporting, data warehousing, batch processing
    * **Not ideal**: High-frequency transactional workloads (OLTP)

  For more information, see [DuckDB documentation](https://duckdb.org/why_duckdb).
  """

  use Ecto.Adapters.SQL,
    driver: :ecto_duckdb

  @behaviour Ecto.Adapter.Storage
  @behaviour Ecto.Adapter.Structure

  alias Ecto.Adapters.DuckDB.Codec

  @impl Ecto.Adapter.Storage
  def storage_down(options) do
    db_path = Keyword.fetch!(options, :database)

    case File.rm(db_path) do
      :ok ->
        File.rm(db_path <> "-shm")
        File.rm(db_path <> "-wal")
        :ok

      _otherwise ->
        {:error, :already_down}
    end
  end

  @impl Ecto.Adapter.Storage
  def storage_status(options) do
    db_path = Keyword.fetch!(options, :database)

    if File.exists?(db_path) do
      :up
    else
      :down
    end
  end

  @impl Ecto.Adapter.Storage
  def storage_up(options) do
    database = Keyword.get(options, :database)
    pool_size = Keyword.get(options, :pool_size)

    cond do
      is_nil(database) ->
        raise ArgumentError,
              """
              No DuckDB database path specified. Please check the configuration for your Repo.
              Your config/*.exs file should have something like this in it:

                config :my_app, MyApp.Repo,
                  adapter: Ecto.Adapters.DuckDB,
                  database: "/path/to/database.duckdb"
              """

      File.exists?(database) ->
        {:error, :already_up}

      database == ":memory:" && pool_size != 1 ->
        raise ArgumentError, """
        In memory databases must have a pool_size of 1
        """

      true ->
        {:ok, state} = Duckdbex.Protocol.connect(options)
        :ok = Duckdbex.Protocol.disconnect(:normal, state)
    end
  end

  @impl Ecto.Adapter.Migration
  def supports_ddl_transaction?, do: true

  @impl Ecto.Adapter.Migration
  def lock_for_migrations(_meta, _options, fun) do
    fun.()
  end

  @impl Ecto.Adapter.Structure
  def structure_dump(default, config) do
    path = config[:dump_path] || Path.join(default, "structure.sql")

    with {:ok, contents} <- dump_schema(config),
         {:ok, versions} <- dump_versions(config) do
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, contents <> versions)
      {:ok, path}
    else
      err -> err
    end
  end

  @impl Ecto.Adapter.Structure
  def structure_load(default, config) do
    path = config[:dump_path] || Path.join(default, "structure.sql")

    case run_with_cmd("duckdb", [config[:database], ".read #{path}"]) do
      {_output, 0} -> {:ok, path}
      {output, _} -> {:error, output}
    end
  end

  @impl Ecto.Adapter.Structure
  def dump_cmd(args, opts \\ [], config) when is_list(config) and is_list(args) do
    run_with_cmd("duckdb", [config[:database] | args], opts)
  end

  @impl Ecto.Adapter.Schema
  def autogenerate(:id) do
    # DuckDB doesn't support auto-increment for BIGINT
    # Generate a unique ID using microseconds and process unique integer
    # This ensures uniqueness even for rapid inserts
    System.unique_integer([:monotonic, :positive])
  end

  def autogenerate(:embed_id), do: Ecto.UUID.generate()

  def autogenerate(:binary_id) do
    case Application.get_env(:ecto_duckdbex, :binary_id_type, :string) do
      :string -> Ecto.UUID.generate()
      :binary -> Ecto.UUID.bingenerate()
    end
  end

  ##
  ## Loaders
  ##

  @default_datetime_type :iso8601

  @impl Ecto.Adapter
  def loaders(:boolean, type) do
    [&Codec.bool_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:naive_datetime_usec, type) do
    [&Codec.naive_datetime_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:time, type) do
    [&Codec.time_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:utc_datetime_usec, type) do
    [&Codec.utc_datetime_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:utc_datetime, type) do
    [&Codec.utc_datetime_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:naive_datetime, type) do
    [&Codec.naive_datetime_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:date, type) do
    [&Codec.date_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders({:map, _}, type) do
    [&Codec.json_decode/1, &Ecto.Type.embedded_load(type, &1, :json)]
  end

  @impl Ecto.Adapter
  def loaders({:array, _}, type) do
    [&Codec.json_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:map, type) do
    [&Codec.json_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:float, type) do
    [&Codec.float_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:decimal, type) do
    [&Codec.decimal_decode/1, type]
  end

  @impl Ecto.Adapter
  def loaders(:binary_id, type) do
    case Application.get_env(:ecto_duckdbex, :binary_id_type, :string) do
      :string -> [type]
      :binary -> [Ecto.UUID, type]
    end
  end

  @impl Ecto.Adapter
  def loaders(:uuid, type) do
    case Application.get_env(:ecto_duckdbex, :uuid_type, :string) do
      :string -> []
      :binary -> [type]
    end
  end

  @impl Ecto.Adapter
  def loaders(primitive_type, ecto_type) do
    loader_from_extension(primitive_type, ecto_type)
  end

  ##
  ## Dumpers
  ##

  @impl Ecto.Adapter
  def dumpers(:binary, type) do
    [type, &Codec.blob_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:boolean, type) do
    [type, &Codec.bool_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:decimal, type) do
    [type, &Codec.decimal_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:binary_id, type) do
    case Application.get_env(:ecto_duckdbex, :binary_id_type, :string) do
      :string -> [type]
      :binary -> [type, Ecto.UUID]
    end
  end

  @impl Ecto.Adapter
  def dumpers(:uuid, type) do
    case Application.get_env(:ecto_duckdbex, :uuid_type, :string) do
      :string -> []
      :binary -> [type]
    end
  end

  @impl Ecto.Adapter
  def dumpers(:time, type) do
    [type, &Codec.time_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:utc_datetime, type) do
    dt_type = Application.get_env(:ecto_duckdbex, :datetime_type, @default_datetime_type)
    [type, &Codec.utc_datetime_encode(&1, dt_type)]
  end

  @impl Ecto.Adapter
  def dumpers(:utc_datetime_usec, type) do
    dt_type = Application.get_env(:ecto_duckdbex, :datetime_type, @default_datetime_type)
    [type, &Codec.utc_datetime_encode(&1, dt_type)]
  end

  @impl Ecto.Adapter
  def dumpers(:naive_datetime, type) do
    dt_type = Application.get_env(:ecto_duckdbex, :datetime_type, @default_datetime_type)
    [type, &Codec.naive_datetime_encode(&1, dt_type)]
  end

  @impl Ecto.Adapter
  def dumpers(:naive_datetime_usec, type) do
    dt_type = Application.get_env(:ecto_duckdbex, :datetime_type, @default_datetime_type)
    [type, &Codec.naive_datetime_encode(&1, dt_type)]
  end

  @impl Ecto.Adapter
  def dumpers({:array, _}, type) do
    [type, &Codec.json_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers({:map, _}, type) do
    [&Ecto.Type.embedded_dump(type, &1, :json), &Codec.json_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:map, type) do
    [type, &Codec.json_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(primitive_type, ecto_type) do
    dumper_from_extension(primitive_type, ecto_type)
  end

  ##
  ## HELPERS
  ##

  defp dump_versions(config) do
    table = config[:migration_source] || "schema_migrations"

    # Generate INSERT statements for schema_migrations table
    case run_with_cmd("duckdb", [
           config[:database],
           "-c",
           "SELECT 'INSERT INTO #{table} VALUES (' || version || ', ''' || inserted_at || ''');' FROM #{table}"
         ]) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  end

  defp dump_schema(config) do
    # Use SHOW ALL TABLES and then get CREATE statements for each
    case run_with_cmd("duckdb", [
           config[:database],
           "-c",
           "SELECT sql FROM duckdb_tables() WHERE schema='main'"
         ]) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  end

  defp run_with_cmd(cmd, args, cmd_opts \\ []) do
    unless System.find_executable(cmd) do
      raise "could not find executable `#{cmd}` in path, " <>
              "please guarantee it is available before running ecto commands"
    end

    cmd_opts = Keyword.put_new(cmd_opts, :stderr_to_stdout, true)

    System.cmd(cmd, args, cmd_opts)
  end

  defp extensions do
    Application.get_env(:ecto_duckdbex, :type_extensions, [])
  end

  defp loader_from_extension(primitive_type, ecto_type) do
    loader_from_extension(extensions(), primitive_type, ecto_type)
  end

  defp loader_from_extension([], _primitive_type, ecto_type), do: [ecto_type]

  defp loader_from_extension([extension | other_extensions], primitive_type, ecto_type) do
    case extension.loaders(primitive_type, ecto_type) do
      nil -> loader_from_extension(other_extensions, primitive_type, ecto_type)
      loader -> loader
    end
  end

  defp dumper_from_extension(primitive_type, ecto_type) do
    dumper_from_extension(extensions(), primitive_type, ecto_type)
  end

  defp dumper_from_extension([], _primitive_type, ecto_type), do: [ecto_type]

  defp dumper_from_extension([extension | other_extensions], primitive_type, ecto_type) do
    case extension.dumpers(primitive_type, ecto_type) do
      nil -> dumper_from_extension(other_extensions, primitive_type, ecto_type)
      dumper -> dumper
    end
  end
end
