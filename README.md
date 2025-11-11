# Ecto DuckDB Adapter

An Ecto DuckDB Adapter. Uses [Duckex](https://github.com/promeduck/duckex)
as the driver to communicate with DuckDB.

DuckDB is an embedded analytical database designed for fast analytics on large datasets.
This adapter brings DuckDB's powerful analytical capabilities to Elixir applications through Ecto.

## Caveats and limitations

See [Limitations](https://hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html#module-limitations-and-caveats)
in Hexdocs.

## Installation

```elixir
defp deps do
  [
    {:ecto_sqlite3, "~> 0.17"}
  ]
end
```

## Usage

Define your repo similar to this.

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.SQLite3
end
```

Configure your repository similar to the following. If you want to know more
about the possible options to pass the repository, checkout the documentation
for [`Ecto.Adapters.SQLite`](https://hexdocs.pm/ecto_sqlite3/). It will have
more information on what is configurable.

```elixir
config :my_app,
  ecto_repos: [MyApp.Repo]

config :my_app, MyApp.Repo,
  database: "path/to/my/database.db"
```

## Type Extensions

Type extensions allow custom data types to be stored and retrieved from an SQLite3 database.

This is done by implementing a module with the `Ecto.Adapters.SQLite3.TypeExtension` behaviour which maps types to encoder and decoder functions. Type extensions are activated by adding them to the `ecto_sqlite3` configuration as a list of type extention modules assigned to the `type_extensions` key:

```elixir
config :exqlite:
  type_extensions: [MyApp.TypeExtension]

config :ecto_sqlite3,
  type_extensions: [MyApp.TypeExtension]
```

## Database Encryption

As of version 0.9, `exqlite` supports loading database engines at runtime rather than compiling `sqlite3.c` itself.
This can be used to support database level encryption via alternate engines such as [SQLCipher](https://www.zetetic.net/sqlcipher/design)
or the [Official SEE extension](https://www.sqlite.org/see/doc/trunk/www/readme.wiki). Once you have either of those projects installed
on your system, use the following environment variables during compilation:

```bash
# tell exqlite that we wish to use some other sqlite installation. this will prevent sqlite3.c and friends from compiling
export EXQLITE_USE_SYSTEM=1

# Tell exqlite where to find the `sqlite3.h` file
export EXQLITE_SYSTEM_CFLAGS=-I/usr/local/include/sqlcipher

# tell exqlite which sqlite implementation to use
export EXQLITE_SYSTEM_LDFLAGS=-L/usr/local/lib -lsqlcipher
```

Once you have `exqlite` configured, you can use the `:key` option in the database config to enable encryption:

```elixir
config :my_app, MyApp.Repo,
  database: "path/to/my/encrypted-database.db",
  key: "supersecret'
```

## Benchmarks

We have some benchmarks comparing it against the `MySQL` and `Postgres` adapters.

You can read more about those at [bench/README.md](bench/README.md).

## Running Tests

Running unit tests

```sh
mix test
```

Running integration tests

```sh
EXQLITE_INTEGRATION=true mix test
```

## DuckLake Support

DuckLake is an open table format for DuckDB that provides:

- **ACID Transactions**: Multi-table transaction support
- **Schema Evolution**: Track schema changes over time
- **Time Travel**: Query data at specific snapshot versions
- **Parquet Storage**: Data stored in open Parquet format for interoperability

### Quick Start with DuckLake

DuckLake stores metadata in a `.ducklake` file and data in Parquet files in a `.files` directory.

#### 1. Setup with Duckex

```elixir
# Start a connection
{:ok, conn} = Duckex.start_link(database: "my_app.duckdb")

# Install and load the ducklake extension
Duckex.query!(conn, "INSTALL ducklake", [])
Duckex.query!(conn, "LOAD ducklake", [])

# Attach a DuckLake database
Duckex.query!(conn, "ATTACH 'ducklake:analytics.ducklake' AS analytics_db", [])
Duckex.query!(conn, "USE analytics_db", [])

# Create tables and insert data
Duckex.query!(conn, "CREATE TABLE events (id INTEGER, name VARCHAR, created_at TIMESTAMP)", [])
Duckex.query!(conn, "INSERT INTO events VALUES (1, 'User Login', NOW())", [])
```

#### 2. Using DuckLake Helper Functions

The adapter provides helper functions for DuckLake operations:

```elixir
alias Ecto.Adapters.DuckDB.DuckLake

# View snapshot history
DuckLake.snapshots(MyApp.Repo)

# Get table information
{:ok, info} = DuckLake.table_info(MyApp.Repo, "events")

# Expire old snapshots (keep last 10)
DuckLake.expire_snapshots(MyApp.Repo, retain_last: 10)

# Clean up orphaned files
DuckLake.cleanup_old_files(MyApp.Repo)

# Merge small files
DuckLake.merge_adjacent_files(MyApp.Repo, "events")
```

#### 3. Example: Loading CSV Data into DuckLake

```elixir
# setup_ducklake.exs
{:ok, conn} = Duckex.start_link(database: "data.duckdb")

# Install extension
Duckex.query!(conn, "INSTALL ducklake", [])
Duckex.query!(conn, "LOAD ducklake", [])

# Attach DuckLake
Duckex.query!(conn, "ATTACH 'ducklake:my_data.ducklake' AS my_db", [])
Duckex.query!(conn, "USE my_db", [])

# Create table
Duckex.query!(conn, """
CREATE TABLE trains (
  id INTEGER,
  service_number INTEGER,
  station_code VARCHAR,
  company_name VARCHAR
)
""", [])

# Load data from CSV
Duckex.query!(conn, """
INSERT INTO trains
SELECT
  ROW_NUMBER() OVER () as id,
  service_number,
  station_code,
  company_name
FROM read_csv_auto('data.csv', header = true)
""", [])

# Verify parquet files were created
File.ls!("my_data.ducklake.files")
# => ["main"]
```

#### 4. Verifying Parquet Files

After inserting data, DuckLake automatically creates Parquet files:

```bash
$ ls -lh my_data.ducklake.files/main/trains/
-rw-r--r--  1 user  staff   93K  ducklake-xxx.parquet
```

These Parquet files can be read by any tool that supports the format (pandas, Spark, etc.).

#### 5. Querying Snapshots

DuckLake creates snapshots automatically on schema changes and data modifications:

```elixir
# View all snapshots
Duckex.query!(conn, "SELECT * FROM ducklake_snapshots('my_db')", [])

# Snapshots show:
# - snapshot_id: Numeric identifier
# - snapshot_time: When the snapshot was created
# - schema_version: Schema version at this point
# - changes: What changed (tables created, data inserted, etc.)
```

### Important Notes

1. **Single Writer**: DuckDB allows only one writer at a time. Always use `pool_size: 1` in your config.

2. **File Structure**:
   ```
   my_app.duckdb              # Setup database
   my_data.ducklake           # DuckLake metadata
   my_data.ducklake.files/    # Parquet data files
     └── main/                # Default schema
         └── table_name/      # Table directory
             ├── ducklake-xxx.parquet        # Data file
             └── ducklake-yyy-delete.parquet # Deletion records
   ```

3. **Extension Installation**: The `ducklake` extension must be installed and loaded before ATTACHing a DuckLake database.

4. **Limitations**: DuckLake does not support:
   - Indexes
   - Primary key constraints (can define but not enforced)
   - Foreign key constraints
   - UNIQUE constraints
   - CHECK constraints

### Complete Example

See `sample_phoenix/setup_ducklake.exs` in the parent repository for a complete working example that:
- Installs the DuckLake extension
- Creates a DuckLake database
- Loads data from a remote CSV
- Creates Parquet files
- Demonstrates snapshot management

Run it with:
```bash
cd sample_phoenix
mix run setup_ducklake.exs
```

### Resources

- [DuckLake Official Documentation](https://ducklake.select/)
- [DuckDB DuckLake Extension](https://duckdb.org/docs/stable/core_extensions/ducklake)
- [DuckLake Specification](https://ducklake.select/docs/stable/)

