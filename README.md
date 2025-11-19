# Ecto Adapter for DuckDBex

An Ecto adapter for DuckDB using the [duckdbex](https://github.com/AlexR2D2/duckdbex) Elixir NIF library instead of Rust bindings.

## Overview

This project provides:

1. **DBConnection Protocol** - Implementation using duckdbex API
2. **Ecto Adapter** - Full Ecto 3.x adapter for DuckDB
3. **Sample Phoenix Project** - Working example with migrations

## Features

- ✅ Full Ecto adapter implementation
- ✅ DBConnection protocol using duckdbex (no Rust compilation required)
- ✅ Support for migrations, transactions, and queries
- ✅ **Multi-statement query support** via `exec!()` function
- ✅ **Automatic extension installation** from config (core, community, nightly, custom)
- ✅ Type conversions (dates, timestamps, decimals, JSON, etc.)
- ✅ Advanced DuckDB features (secrets, attach, configs, USE)
- ✅ Sample Phoenix project with DuckLake + WebDAV remote storage

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:ecto_duckdbex, "~> 0.1.0"},
    {:ecto_sql, "~> 3.13"},
    {:duckdbex, "~> 0.3.5"}
  ]
end
```

## Configuration

Configure your repository:

```elixir
# config/config.exs
config :my_app, MyApp.Repo,
  adapter: Ecto.Adapters.DuckDBex,
  database: "path/to/database.duckdb",
  # DuckDB only allows one writer at a time
  pool_size: 1
```

### Extension Installation

Automatically install and load DuckDB extensions during connection initialization:

```elixir
config :my_app, MyApp.Repo,
  adapter: Ecto.Adapters.DuckDBex,
  database: "path/to/database.duckdb",
  pool_size: 1,

  # Install and load extensions
  extensions: [
    # Simple atom installs from default source and auto-loads
    :httpfs,
    :parquet,

    # Tuple with options for more control
    {:netquack, source: :community},
    {:spatial, source: :core},
    {:my_extension, source: "https://example.com/repo", load: false}
  ]
```

**Extension Options:**

- `:source` - Installation source:
  - `:default` - Default DuckDB registry (default)
  - `:core` - Core extensions repository
  - `:nightly` - Core nightly builds (`core_nightly`)
  - `:community` - Community extensions repository
  - URL string - Custom repository URL
- `:force` - Force reinstall even if already installed (default: `false`)
- `:load` - Automatically load after install (default: `true`)

Extensions are installed during connection initialization, before any queries are executed.

### Advanced DuckDB Features

The adapter supports advanced DuckDB features for working with remote storage, multiple databases, and custom configurations:

#### Secrets

Create DuckDB secrets for accessing remote storage (S3, WebDAV, etc.):

```elixir
config :my_app, MyApp.Repo,
  adapter: Ecto.Adapters.DuckDBex,
  database: "path/to/database.duckdb",
  pool_size: 1,

  secrets: [
    # Simple format with all parameters in one array
    {:my_s3_secret, [
      key_id: "AKIAIOSFODNN7EXAMPLE",
      secret: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      type: :s3,
      region: "us-east-1"
    ]},

    # WebDAV secret for services like Hetzner Storagebox
    {:webdav_secret, [
      username: System.get_env("WEBDAV_USER"),
      password: System.get_env("WEBDAV_PASSWORD"),
      type: :webdav,
      scope: "webdav://example.com"
    ]}
  ]
```

**Secret Options:**
- `type` - Secret type (`:s3`, `:webdav`, etc.)
- `scope` - URL scope where the secret applies
- `persistent` - Make secret persistent across sessions (default: `false`)

#### Attach Databases

Attach additional DuckDB or DuckLake databases:

```elixir
config :my_app, MyApp.Repo,
  adapter: Ecto.Adapters.DuckDBex,
  database: "path/to/database.duckdb",
  pool_size: 1,

  attach: [
    # Attach DuckLake with remote storage
    {"ducklake:analytics.ducklake", [
      as: :analytics_db,
      options: [
        DATA_PATH: "s3://my-bucket/analytics"
      ]
    ]},

    # Attach regular DuckDB database
    {"path/to/other.duckdb", [
      as: :other_db
    ]}
  ]
```

#### Database Configurations

Set database-specific configuration options:

```elixir
config :my_app, MyApp.Repo,
  adapter: Ecto.Adapters.DuckDBex,
  database: "path/to/database.duckdb",
  pool_size: 1,

  configs: [
    analytics_db: [
      data_inlining_row_limit: 10000,
      parquet_compression: :zstd,
      parquet_compression_level: 20,
      parquet_version: 2
    ]
  ]
```

#### USE Statement

Switch to a specific attached database as the default:

```elixir
config :my_app, MyApp.Repo,
  adapter: Ecto.Adapters.DuckDBex,
  database: "path/to/database.duckdb",
  pool_size: 1,

  # Switch to attached database
  use: :analytics_db
```

All tables created by migrations will be created in the specified database.

#### Complete Example

Here's a complete example using all advanced features together:

```elixir
config :my_app, MyApp.Repo,
  adapter: Ecto.Adapters.DuckDBex,
  database: "local.duckdb",
  pool_size: 1,

  # 1. Install required extensions
  extensions: [
    :httpfs,
    {:webdavfs, source: :community}
  ],

  # 2. Create secrets for remote access
  secrets: [
    {:storage_secret, [
      username: System.get_env("STORAGE_USER"),
      password: System.get_env("STORAGE_PASSWORD"),
      type: :webdav,
      scope: "webdav://storage.example.com"
    ]}
  ],

  # 3. Attach DuckLake with remote storage
  attach: [
    {"ducklake:analytics.ducklake", [
      as: :analytics,
      options: [
        DATA_PATH: "webdav://storage.example.com/analytics"
      ]
    ]}
  ],

  # 4. Configure database settings
  configs: [
    analytics: [
      parquet_compression: :zstd,
      parquet_compression_level: 20
    ]
  ],

  # 5. Use attached database as default
  use: :analytics
```

Define your repository:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.DuckDBex
end
```

## Multi-Statement Query Support

The adapter supports executing multi-statement queries that are not supported by standard prepared statements:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.DuckDBex

  # Enable multi-statement query support
  use Ecto.Adapters.DuckDBex.RawQuery
end
```

Now you can use `exec!/1` to execute complex multi-statement queries:

```elixir
# Install and load extensions
MyApp.Repo.exec!("""
  INSTALL httpfs;
  LOAD httpfs;
  INSTALL parquet;
  LOAD parquet;
""")

# Complex queries with CTEs
MyApp.Repo.exec!("""
  WITH data AS (
    SELECT * FROM read_parquet('s3://bucket/file.parquet')
  )
  SELECT * FROM data WHERE condition = true;
""")
```

This is useful for:
- Installing and loading DuckDB extensions
- Executing multiple DDL statements together
- Complex queries with CTEs and WITH clauses
- Queries that don't work with prepared statements

## Sample Phoenix Project

The `sample_phoenix/` directory contains a fully working Phoenix application using this adapter:

```bash
cd sample_phoenix
mix deps.get
mix ecto.create
mix ecto.migrate
```

This will create a DuckDB database and run migrations to create tables.

## Key Differences from ecto_duckdb

This adapter uses `duckdbex` (pure Elixir NIF) instead of the Rust-based connector:

- **No Rust compilation** - Faster setup and fewer dependencies
- **Uses duckdbex API** - Native Elixir interface to DuckDB
- **Same Ecto interface** - Drop-in replacement for most use cases

## Architecture

```
lib/
├── duckdbex/
│   ├── protocol.ex       # DBConnection implementation
│   ├── query.ex          # Query struct
│   ├── result.ex         # Result struct
│   └── error.ex          # Error exception
└── ecto/adapters/
    └── duckdbex/
        ├── codec.ex      # Type encoding/decoding
        ├── connection.ex # SQL query building
        ├── data_type.ex  # DuckDB data types
        └── duckdbex.ex   # Main adapter module
```

## Limitations

- **Pool Size**: Must be set to 1 (DuckDB single-writer limitation)
- **Transactions**: Fully supported
- **Concurrent Reads**: Supported with proper connection pooling

## Development

```bash
# Get dependencies
mix deps.get

# Run tests (requires Elixir/Erlang installed)
mix test

# Format code
mix format

# Run sample Phoenix app
cd sample_phoenix
mix phx.server
```

## Credits

Based on [ecto_duckdb](https://github.com/midwork-finds-jobs/ecto_duckdb) but using duckdbex instead of Rust bindings.

## License

MIT