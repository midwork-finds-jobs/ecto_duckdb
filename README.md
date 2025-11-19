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
- ✅ Type conversions (dates, timestamps, decimals, JSON, etc.)
- ✅ Sample Phoenix project with working migrations

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

Define your repository:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.DuckDBex
end
```

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