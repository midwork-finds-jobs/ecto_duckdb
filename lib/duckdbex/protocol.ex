defmodule Duckdbex.Protocol do
  @moduledoc false

  use DBConnection

  alias Duckdbex.Result

  require Logger

  ## ------------------------------------------------------------------
  ## Logging Helpers
  ## ------------------------------------------------------------------

  # Log debug messages only if logging is enabled at debug level
  defp log_debug(%{log_level: log_level}, message) when log_level == :debug do
    Logger.debug(message)
  end

  defp log_debug(_state, _message), do: :ok

  ## ------------------------------------------------------------------
  ## gen_server Function Definitions
  ## ------------------------------------------------------------------

  @impl true
  def connect(opts) do
    # Determine log level based on :log option
    # false = no debug logging, true/:debug = debug logging
    # :info/:warning/:error = only log at that level or higher
    log_level = case opts[:log] do
      false -> :none
      true -> :debug
      level when level in [:debug, :info, :warning, :error] -> level
      _ -> :debug
    end

    state = %{log_level: log_level}
    log_debug(state, "Initiating connect: #{inspect(opts)}")

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

    # Process post-connection configuration similar to ecto_duck
    extensions = opts[:extensions] || []
    secrets = opts[:secrets] || []
    attach = opts[:attach] || []
    configs = opts[:configs] || []

    # Install and load extensions first (including webdavfs if needed for secrets)
    Enum.each(extensions, fn ext ->
      install_extension!(conn, ext, state)
    end)

    # Create secrets first (they might be needed for attaching)
    Enum.each(secrets, fn
      {name, {spec, secret_opts}} ->
        create_secret_direct!(conn, name, spec, secret_opts, state)

      {name, spec} ->
        create_secret_direct!(conn, name, spec, [], state)
    end)

    # Then attach databases
    Enum.each(attach, fn
      {path, attach_opts} ->
        attach_direct!(conn, path, attach_opts, state)

      {path, attach_opts, _conn_opts} ->
        attach_direct!(conn, path, attach_opts, state)
    end)

    # Then set database-specific configurations
    Enum.each(configs, fn {db_name, db_configs} ->
      Enum.each(db_configs, fn {option_name, option_value} ->
        set_config_direct!(conn, db_name, option_name, option_value, state)
      end)
    end)

    # Then switch to the specified database
    if opts[:use] do
      execute_init_query!(conn, "USE #{opts[:use]}", [], state)
    end

    # Store db, conn references, and log level
    state = %{db: db, conn: conn, cache: %{}, log_level: log_level}

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
    # Check if this is a raw multi-statement query
    if is_map(query) and Map.has_key?(query, :__struct__) and
         query.__struct__ == Ecto.Adapters.DuckDBex.RawQuery.RawQuery do
      # Execute raw multi-statement query bypassing prepared statements
      log_debug(state, "Executing raw multi-statement query")

      case Duckdbex.query(state.conn, query.sql) do
        {:ok, result_ref} ->
          rows = Duckdbex.fetch_all(result_ref)
          columns = extract_columns(result_ref)
          Duckdbex.release(result_ref)
          result = %Result{rows: rows || [], columns: columns, num_rows: length(rows || [])}
          log_debug(state, "Raw query successful")
          {:ok, query, result, state}

        {:error, err} ->
          Logger.error("Raw query error: #{inspect(err)}")
          {:error, err, state}
      end
    else
      # Standard prepared statement execution
      log_debug(state, "Executing query with stmt: #{inspect(query.stmt)}, params: #{inspect(params)}")

      case execute_query(state.conn, query.stmt, params, cache) do
        {:ok, result} ->
          log_debug(state, "Execute successful")
          {:ok, query, result, state}

        {:error, err} ->
          Logger.error("Execute error: #{inspect(err)}")
          {:error, err, state}
      end
    end
  end

  @impl true
  def handle_fetch(_query, _cursor, _opts, %{} = state) do
    # Since we fetch all results at once, just return empty result
    {:halt, %Result{rows: [], columns: []}, state}
  end

  @impl true
  def handle_prepare(query, opts, %{cache: cache} = state) do
    log_debug(state, "Preparing query: #{inspect(query.query)}")

    # FIXME: Disable this when DuckLake supports PRIMARY KEYs
    # https://github.com/duckdb/ducklake/discussions/323
    # Check if the currently used default database is a DuckLake
    # If so, remove the PRIMARY KEY constraint
    fixed_query_str =
      if should_fix_ducklake_primary_key?(opts) do
        log_debug(state, "Removed non-supported 'PRIMARY KEY' from query for DuckLake database")

        query.query
        |> String.replace("BIGINT PRIMARY KEY", "BIGINT NOT NULL")
        # For schema_migrations, use BIGINT instead of INTEGER for version column
        # because migration timestamps are too large for INT32
        |> String.replace(~r/"version" INTEGER PRIMARY KEY/, "\"version\" BIGINT NOT NULL")
        |> String.replace("INTEGER PRIMARY KEY", "INTEGER NOT NULL")
      else
        query.query
      end

    case Duckdbex.prepare_statement(state.conn, fixed_query_str) do
      {:ok, stmt_ref} ->
        # Use the reference itself as the cache key
        new_cache = Map.put(cache, stmt_ref, stmt_ref)
        log_debug(state, "Query prepared with stmt_ref: #{inspect(stmt_ref)}")
        {:ok, %{query | stmt: stmt_ref}, %{state | cache: new_cache}}

      {:error, err} ->
        Logger.error("Prepare error: #{inspect(err)}")
        error = %Duckdbex.Error{message: "#{inspect(err)}"}
        {:error, error, state}
    end
  end

  # Check if we should apply the DuckLake PRIMARY KEY workaround
  defp should_fix_ducklake_primary_key?(opts) do
    repo_config = if opts[:repo], do: opts[:repo].config(), else: []
    use_db = repo_config[:use]
    attach = repo_config[:attach] || []

    if use_db do
      # Find the attach entry where :as matches :use
      Enum.any?(attach, fn
        {path, attach_opts} ->
          as = attach_opts[:as] || attach_opts[:AS]
          as == use_db && String.starts_with?(to_string(path), "ducklake:")

        {path, attach_opts, _conn_opts} ->
          as = attach_opts[:as] || attach_opts[:AS]
          as == use_db && String.starts_with?(to_string(path), "ducklake:")
      end)
    else
      false
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

  ## ------------------------------------------------------------------
  ## Post-Connection Initialization Helpers
  ## ------------------------------------------------------------------

  # Execute a query during connection initialization
  defp execute_init_query!(conn, sql, params, state) do
    result = if params == [] do
      Duckdbex.query(conn, sql)
    else
      Duckdbex.query(conn, sql, params)
    end

    case result do
      {:ok, result_ref} ->
        Duckdbex.fetch_all(result_ref)
        Duckdbex.release(result_ref)
        log_debug(state, "Executed init query: #{sql}")
        :ok

      {:error, reason} ->
        raise Duckdbex.Error, message: "Init query failed: #{inspect(reason)}"
    end
  end

  # Create a DuckDB secret
  # Supports two formats:
  # 1. Separate spec and opts: create_secret_direct!(conn, name, [username: "x", password: "y"], [type: :webdav, scope: "..."], state)
  # 2. Combined single array: create_secret_direct!(conn, name, [username: "x", password: "y", type: :webdav, scope: "..."], [], state)
  defp create_secret_direct!(conn, name, spec, secret_opts, state) do
    # Special keys that should be treated as secret options, not spec parameters
    secret_option_keys = [:type, :scope, :persistent]

    # If secret_opts is empty and spec contains secret option keys, split them
    {final_spec, final_opts} =
      if secret_opts == [] && Enum.any?(spec, fn {k, _v} -> k in secret_option_keys end) do
        # Split spec into actual spec parameters and secret options
        {spec_params, opts_params} = Enum.split_with(spec, fn {k, _v} -> k not in secret_option_keys end)
        {spec_params, opts_params}
      else
        # Use as-is (original format with separate arrays)
        {spec, secret_opts}
      end

    spec_sql = format_secret_options_inline(final_spec)
    type = final_opts[:type] || :s3
    scope = if val = final_opts[:scope], do: ", SCOPE '#{escape(val)}'", else: ""
    persistent = if final_opts[:persistent], do: "PERSISTENT ", else: ""

    # Add comma between TYPE and spec_sql if spec_sql is not empty
    spec_part = if spec_sql != "", do: ", #{spec_sql}", else: ""
    # SCOPE goes inside the parentheses after the spec parameters
    query_sql = "CREATE #{persistent}SECRET #{name} (TYPE #{type}#{spec_part}#{scope})"

    log_debug(state, "Creating secret with SQL: #{query_sql}")

    case Duckdbex.query(conn, query_sql) do
      {:ok, result_ref} ->
        Duckdbex.release(result_ref)
        log_debug(state, "Created secret: #{name}")
        :ok

      {:error, reason} ->
        error_msg = """
        Failed to create secret '#{name}': #{inspect(reason)}

        Troubleshooting:
        - Verify secret type is valid (:s3, :webdav, etc.)
        - Check scope format (e.g., 's3://bucket' or 'webdav://host')
        - Ensure required extensions are installed (webdavfs for WebDAV)
        - Verify credentials are correct
        """
        raise Duckdbex.Error, message: error_msg
    end
  end

  # Attach a database
  defp attach_direct!(conn, path, attach_opts, state) do
    path = escape(path)

    val = attach_opts[:as] || attach_opts[:AS]
    as = if val, do: " AS #{val}", else: ""

    options = format_attach_options(attach_opts[:options])
    options_part = if options == "", do: "", else: " (#{options})"

    query_sql = "ATTACH '#{path}'#{as}#{options_part}"

    case Duckdbex.query(conn, query_sql) do
      {:ok, result_ref} ->
        Duckdbex.release(result_ref)
        log_debug(state, "Attached database: #{path}")
        :ok

      {:error, reason} ->
        error_msg = """
        Failed to attach database '#{path}': #{inspect(reason)}

        Troubleshooting:
        - Verify the database file/path exists
        - Check if using DuckLake format (ducklake:path.ducklake)
        - Ensure secrets are configured for remote storage
        - Verify DATA_PATH option is correct if using remote storage
        - Check file permissions
        """
        raise Duckdbex.Error, message: error_msg
    end
  end

  # Set database-specific configuration
  defp set_config_direct!(conn, db_name, option_name, option_value, state) do
    # Convert option_name from snake_case atom to lowercase string
    option_str = option_name |> to_string() |> String.downcase()

    # Format the value based on its type
    value_str =
      cond do
        is_atom(option_value) -> "'#{option_value}'"
        is_binary(option_value) -> "'#{escape(option_value)}'"
        is_number(option_value) -> "#{option_value}"
        true -> "'#{option_value}'"
      end

    # Use the CALL db.set_option() syntax for database-specific settings
    query_sql = "CALL #{db_name}.set_option('#{option_str}', #{value_str})"

    case Duckdbex.query(conn, query_sql) do
      {:ok, result_ref} ->
        Duckdbex.release(result_ref)
        log_debug(state, "Set config #{db_name}.#{option_str} = #{value_str}")
        :ok

      {:error, reason} ->
        error_msg = """
        Failed to set config '#{db_name}.#{option_str}': #{inspect(reason)}

        Troubleshooting:
        - Verify database '#{db_name}' is attached
        - Check if option name '#{option_str}' is valid for this database type
        - Ensure option value type is correct (string, number, atom)
        - Verify the database supports configuration changes
        """
        raise Duckdbex.Error, message: error_msg
    end
  end

  # Helper to escape SQL string values
  defp escape(val), do: String.replace(to_string(val), "'", "''")

  # Format attach options for ATTACH statement
  defp format_attach_options(nil), do: ""

  defp format_attach_options(opts) do
    opts
    |> Enum.flat_map(fn
      {_key, false} -> []
      {key, true} -> ["#{key}"]
      {key, value} when is_atom(value) or is_number(value) -> ["#{key} #{value}"]
      {key, value} -> ["#{key} '#{escape(value)}'"]
    end)
    |> Enum.join(", ")
  end

  # Format secret options for CREATE SECRET statement (inline values)
  defp format_secret_options_inline(opts) do
    opts
    |> Enum.map(fn
      {name, val} when is_atom(val) ->
        "#{name} #{val}"

      {name, val} ->
        "#{name} '#{escape(val)}'"
    end)
    |> Enum.join(", ")
  end

  ## ------------------------------------------------------------------
  ## Extension Installation Helpers
  ## ------------------------------------------------------------------

  # Install a DuckDB extension during connection initialization.
  #
  # Extensions can be specified as:
  # - An atom (e.g., `:httpfs`) - installs from default source
  # - A tuple `{name, opts}` with options:
  #   - `:source` - `:default`, `:core`, `:nightly`, `:community`, or URL string
  #   - `:force` - boolean to force reinstall
  #   - `:load` - boolean to automatically load after install (default: true)
  #
  # Examples:
  #   install_extension!(conn, :httpfs)
  #   install_extension!(conn, {:parquet, source: :community, load: false})
  #   install_extension!(conn, {:httpfs, source: :nightly, force: true})
  defp install_extension!(conn, name, state) when is_atom(name) do
    install_extension!(conn, {name, []}, state)
  end

  defp install_extension!(conn, {name, opts}, state) do
    # Build FROM clause based on source option
    from =
      case opts[:source] do
        :core -> " FROM core"
        :nightly -> " FROM core_nightly"
        :community -> " FROM community"
        nil -> ""
        :default -> ""
        repo when is_binary(repo) -> " FROM '#{escape(repo)}'"
      end

    # Add FORCE if requested
    force = if opts[:force], do: "FORCE ", else: ""

    # Install the extension
    install_sql = "#{force}INSTALL #{name}#{from}"
    log_debug(state, "Installing extension: #{install_sql}")

    case Duckdbex.query(conn, install_sql) do
      {:ok, result_ref} ->
        Duckdbex.release(result_ref)
        log_debug(state, "Installed extension: #{name}")

        # Load extension if requested (default: true)
        if Keyword.get(opts, :load, true) do
          load_sql = "LOAD #{name}"
          log_debug(state, "Loading extension: #{load_sql}")

          case Duckdbex.query(conn, load_sql) do
            {:ok, load_result_ref} ->
              Duckdbex.release(load_result_ref)
              log_debug(state, "Loaded extension: #{name}")
              :ok

            {:error, reason} ->
              error_msg = """
              Failed to load extension '#{name}': #{inspect(reason)}

              Troubleshooting:
              - Extension was installed but failed to load
              - Check if extension is compatible with your DuckDB version
              - Verify extension binary is not corrupted
              """
              raise Duckdbex.Error, message: error_msg
          end
        else
          :ok
        end

      {:error, reason} ->
        error_msg = """
        Failed to install extension '#{name}': #{inspect(reason)}

        Troubleshooting:
        - Verify extension name is correct
        - Check network connection if downloading from repository
        - Ensure source is valid (:default, :core, :nightly, :community, or URL)
        - Try with :force option to reinstall
        - Check DuckDB extension compatibility
        """
        raise Duckdbex.Error, message: error_msg
    end
  end
end
