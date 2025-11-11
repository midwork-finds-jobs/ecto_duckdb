# Ecto DuckDB Adapter

An Ecto adapter for [DuckDB](https://duckdb.org/), the in-process analytical database.

DuckDB is an embedded analytical database designed for fast analytics on large datasets.
This adapter brings DuckDB's powerful analytical capabilities to Elixir applications through Ecto.

## Features

- Full Ecto 3.x support with migrations, queries, and transactions
- Support for standard DuckDB databases
- Support for DuckLake (open table format with ACID transactions and time travel)
- Direct querying of remote CSV/Parquet files
- Analytical queries on large datasets

## Caveats and Limitations

**Important**: DuckDB only allows **one writer at a time**. Always configure `pool_size: 1` in your repository configuration.

Additional limitations:
- No support for indexes (DuckDB is column-oriented and doesn't use traditional indexes)
- Primary keys can be defined but are not enforced
- Foreign key constraints are not enforced
- UNIQUE and CHECK constraints are not enforced
- Limited support for some SQL features compared to PostgreSQL

## Installation

Add `ecto_duckdb` to your list of dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:ecto_duckdb, "~> 0.1"}
  ]
end
```

## Basic Usage

### 1. Define Your Repository

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.DuckDB
end
```

### 2. Configure Your Repository

In `config/config.exs`:

```elixir
config :my_app,
  ecto_repos: [MyApp.Repo]
```

In `config/dev.exs`:

```elixir
config :my_app, MyApp.Repo,
  database: Path.expand("../my_app_dev.duckdb", __DIR__),
  # DuckDB only allows one writer at a time
  pool_size: 1,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true
```

In `config/test.exs`:

```elixir
config :my_app, MyApp.Repo,
  database: Path.expand("../my_app_test.duckdb", __DIR__),
  # DuckDB only allows one writer at a time
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox
```

### 3. Add to Your Application Supervision Tree

In `lib/my_app/application.ex`:

```elixir
def start(_type, _args) do
  children = [
    MyApp.Repo,
    # ... other children
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

## Working with Schemas and Queries

### Defining Schemas

Define Ecto schemas as you normally would:

```elixir
defmodule MyApp.Blog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :body, :text
    field :published, :boolean, default: false
    field :view_count, :integer, default: 0

    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :body, :published])
    |> validate_required([:title, :body])
  end
end
```

### Creating Migrations

```elixir
defmodule MyApp.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :string
      add :body, :text
      add :published, :boolean, default: false
      add :view_count, :integer, default: 0

      timestamps()
    end
  end
end
```

Run migrations:

```bash
mix ecto.migrate
```

### Querying Data

Use Ecto's query DSL for powerful analytical queries:

```elixir
import Ecto.Query

# Simple queries
MyApp.Repo.all(from p in Post, where: p.published == true)

# Aggregations (DuckDB excels at these!)
MyApp.Repo.one(
  from p in Post,
  select: %{
    total: count(p.id),
    avg_views: avg(p.view_count),
    max_views: max(p.view_count)
  }
)

# Window functions
MyApp.Repo.all(
  from p in Post,
  select: %{
    title: p.title,
    view_count: p.view_count,
    rank: over(row_number(), order_by: [desc: p.view_count])
  }
)

# Querying remote files directly
MyApp.Repo.query!("""
  SELECT * FROM read_csv_auto('https://example.com/data.csv')
  LIMIT 10
""")
```

## Running Tests

Running unit tests

```sh
mix test
```

Running integration tests

```sh
DUCKDB_INTEGRATION=true mix test
```

## Advanced Features

### Querying Remote Data

DuckDB can directly query remote CSV and Parquet files:

```elixir
# Install httpfs extension
MyApp.Repo.query!("INSTALL httpfs", [])
MyApp.Repo.query!("LOAD httpfs", [])

# Query remote CSV
result = MyApp.Repo.query!("""
  SELECT *
  FROM read_csv_auto('https://example.com/data.csv.gz')
  LIMIT 100
""")

# Query remote Parquet
result = MyApp.Repo.query!("""
  SELECT *
  FROM read_parquet('s3://bucket/data.parquet')
  WHERE date >= '2024-01-01'
""")
```

### Window Functions and Analytics

DuckDB provides powerful analytical capabilities:

```elixir
import Ecto.Query

# Moving averages
MyApp.Repo.all(
  from p in Post,
  select: %{
    date: p.inserted_at,
    views: p.view_count,
    moving_avg: over(
      avg(p.view_count),
      order_by: [asc: p.inserted_at],
      partition_by: fragment("DATE_TRUNC('month', ?)", p.inserted_at)
    )
  }
)

# Percentiles
MyApp.Repo.one(
  from p in Post,
  select: %{
    median_views: fragment("percentile_cont(0.5) WITHIN GROUP (ORDER BY ?)", p.view_count),
    p95_views: fragment("percentile_cont(0.95) WITHIN GROUP (ORDER BY ?)", p.view_count)
  }
)
```

## DuckLake Support

DuckLake is an open table format for DuckDB that provides:

- **ACID Transactions**: Multi-table transaction support
- **Schema Evolution**: Track schema changes over time
- **Time Travel**: Query data at specific snapshot versions
- **Parquet Storage**: Data stored in open Parquet format for interoperability

### DuckLake Repository Setup

DuckLake stores metadata in a `.ducklake` file and data in Parquet files in a `.files` directory.

#### 1. Define a DuckLake Repository

```elixir
defmodule MyApp.AnalyticsRepo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.DuckDB
end
```

#### 2. Configure the DuckLake Repository

In `config/config.exs`:

```elixir
config :my_app,
  ecto_repos: [MyApp.Repo, MyApp.AnalyticsRepo]
```

In `config/dev.exs`:

```elixir
config :my_app, MyApp.AnalyticsRepo,
  attach: [
    {
      "ducklake:#{Path.expand("../my_app_analytics.ducklake", __DIR__)}",
      [
        as: :analytics_db,
        # Optional: https://ducklake.select/docs/stable/duckdb/usage/connecting#parameters
        # options: [READ_ONLY: true]
      ]
    }
  ],
  configs: [
    # DuckLake configuration options
    # https://ducklake.select/docs/stable/duckdb/usage/configuration
    analytics_db: [
      data_inlining_row_limit: 10000,
      parquet_compression: :zstd,
      parquet_compression_level: 20,
      parquet_version: 2
    ]
  ],
  use: :analytics_db,
  timeout: 600_000, # 10 minutes for long-running analytical queries
  # DuckDB only allows one writer at a time
  pool_size: 1,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true
```

#### 3. Run Migrations

Create migrations in `priv/analytics_repo/migrations/`:

```elixir
defmodule MyApp.AnalyticsRepo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :name, :string
      add :user_id, :integer
      add :metadata, :map

      timestamps()
    end
  end
end
```

Run migrations:

```bash
mix ecto.migrate -r MyApp.AnalyticsRepo
```

#### 4. Using Your DuckLake Repository

Use it like any other Ecto repository:

```elixir
# Define a schema
defmodule MyApp.Analytics.Event do
  use Ecto.Schema

  schema "events" do
    field :name, :string
    field :user_id, :integer
    field :metadata, :map

    timestamps()
  end
end

# Insert data
%MyApp.Analytics.Event{
  name: "user_login",
  user_id: 123,
  metadata: %{ip: "192.168.1.1"}
}
|> MyApp.AnalyticsRepo.insert()

# Query data
import Ecto.Query

MyApp.AnalyticsRepo.all(
  from e in MyApp.Analytics.Event,
  where: e.name == "user_login",
  select: count(e.id)
)
```

#### 5. Loading Remote CSV Data

You can directly query remote CSV files and insert them into your DuckLake tables:

```elixir
# Install httpfs extension for remote file access
MyApp.AnalyticsRepo.query!("INSTALL httpfs", [])
MyApp.AnalyticsRepo.query!("LOAD httpfs", [])

# Load data from remote CSV
MyApp.AnalyticsRepo.query!("""
  INSERT INTO events (name, user_id, inserted_at, updated_at)
  SELECT
    event_name,
    user_id,
    NOW(),
    NOW()
  FROM read_csv_auto('https://example.com/data.csv', header = true)
""", [])
```

### DuckLake Helper Functions

The adapter provides helper functions for DuckLake operations:

```elixir
alias Ecto.Adapters.DuckDB.DuckLake

# View snapshot history
DuckLake.snapshots(MyApp.AnalyticsRepo)

# Get table information
{:ok, info} = DuckLake.table_info(MyApp.AnalyticsRepo, "events")

# Expire old snapshots (keep last 10)
DuckLake.expire_snapshots(MyApp.AnalyticsRepo, retain_last: 10)

# Clean up orphaned files
DuckLake.cleanup_old_files(MyApp.AnalyticsRepo)

# Merge small files for better performance
DuckLake.merge_adjacent_files(MyApp.AnalyticsRepo, "events")
```

### Verifying Parquet Files

After inserting data, DuckLake automatically creates Parquet files:

```bash
$ ls -lh my_app_analytics.ducklake.files/analytics_db/events/
-rw-r--r--  1 user  staff   93K  ducklake-xxx.parquet
```

These Parquet files can be read by any tool that supports the format (pandas, Spark, DuckDB, etc.), making your data portable and interoperable.

### Querying Snapshots

DuckLake creates snapshots automatically on schema changes and data modifications:

```elixir
# View all snapshots
MyApp.AnalyticsRepo.query!("SELECT * FROM ducklake_snapshots('analytics_db')", [])

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
   my_app_analytics.ducklake           # DuckLake metadata
   my_app_analytics.ducklake.files/    # Parquet data files
     └── analytics_db/                 # Database name (from 'as:' config)
         └── events/                   # Table directory
             ├── ducklake-xxx.parquet        # Data file
             └── ducklake-yyy-delete.parquet # Deletion records
   ```

3. **Extension Installation**: The `ducklake` extension is automatically installed and loaded when you use the `attach` configuration option.

4. **Limitations**: DuckLake does not support:
   - Indexes (DuckDB is column-oriented)
   - Enforced primary key constraints (can define but not enforced)
   - Enforced foreign key constraints
   - UNIQUE constraints
   - CHECK constraints

### Multiple Repositories

You can use both standard DuckDB and DuckLake repositories in the same application:

```elixir
# Regular DuckDB for OLTP-like workloads
config :my_app, MyApp.Repo,
  database: Path.expand("../my_app.duckdb", __DIR__),
  pool_size: 1

# DuckLake for analytics with Parquet storage
config :my_app, MyApp.AnalyticsRepo,
  attach: [{"ducklake:#{Path.expand("../my_app_analytics.ducklake", __DIR__)}", [as: :analytics_db]}],
  use: :analytics_db,
  pool_size: 1
```

### Resources

- [DuckLake Official Documentation](https://ducklake.select/)
- [DuckDB DuckLake Extension](https://duckdb.org/docs/stable/core_extensions/ducklake)
- [DuckLake Specification](https://ducklake.select/docs/stable/)

