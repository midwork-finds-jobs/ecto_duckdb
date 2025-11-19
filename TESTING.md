# Testing Guide

## Prerequisites

1. Install Elixir (1.15+) and Erlang
2. Clone this repository

## Test Steps

### 1. Install Dependencies

```bash
cd ecto_duckdb
mix deps.get
```

#### 2. Test Sample Phoenix Project

```bash
cd sample_phoenix
mix deps.get
```

#### 3. Create Database

```bash
mix ecto.create
```

This should create `sample_phoenix_dev.duckdb` file.

#### 4. Run Migrations

```bash
mix ecto.migrate
```

This will run three migrations:

- `20251027193450_create_posts.exs` - Creates posts table
- `20251028071818_create_users.exs` - Creates users table
- `20251028072213_test_native_datetime_types.exs` - Tests datetime types

Expected output:

```sh
[info] == Running ... SamplePhoenix.Repo.Migrations.CreatePosts.change/0 forward
[info] create table posts
[info] == Migrated ... in 0.0s
...
```

#### 5. Verify Tables

You can verify the tables were created by connecting to the database with DuckDB CLI:

```bash
duckdb sample_phoenix_dev.duckdb

D SELECT table_name FROM information_schema.tables WHERE table_schema='main';
```

Expected tables:

- `posts`
- `users`
- `schema_migrations`

#### 6. Test Basic Operations

Start an IEx session:

```bash
iex -S mix
```

Then try some operations:

```elixir
# Insert a post
alias SamplePhoenix.Repo
alias SamplePhoenix.Blog.Post

{:ok, post} = %Post{}
  |> Post.changeset(%{title: "Test", body: "Hello DuckDB!", published: true})
  |> Repo.insert()

# Query posts
Repo.all(Post)

# Update a post
post
|> Post.changeset(%{title: "Updated Title"})
|> Repo.update()

# Delete a post
Repo.delete(post)
```

## Known Issues

### Issue 1: Column Name Extraction

The current implementation doesn't extract column names from duckdbex results. This may cause issues with some Ecto queries. To fix this, we would need to enhance duckdbex or work around it in the protocol.

### Issue 2: Prepared Statement Caching

The statement caching in the protocol is basic. For production use, this should be improved to properly manage statement lifecycle.

### Issue 3: Transaction Isolation

DuckDB has specific transaction isolation characteristics. Test concurrent transactions carefully.

## Troubleshooting

### Error: "database is locked"

This usually means:

1. Another process has the database open
2. Pool size is > 1 (should be 1 for DuckDB)

**Solution**: Ensure `pool_size: 1` in config.

### Error: "command not found: mix"

Elixir is not installed. Install Elixir and Erlang first.

### Error: "could not compile dependency :duckdbex"

This might be due to missing DuckDB system libraries. Ensure DuckDB is installed:

```bash
# macOS
brew install duckdb

# Linux
curl https://install.duckdb.org | sh
```

## Integration Testing

For a real-world test, try migrating an existing Phoenix app from SQLite or Postgres to DuckDB:

1. Change the adapter in your repo module
2. Update config to use DuckDB database path
3. Set pool_size to 1
4. Run migrations
5. Test your application

## Performance Testing

To test performance:

```elixir
# In IEx
:timer.tc(fn ->
  for _ <- 1..1000 do
    Repo.insert!(%Post{title: "Test", body: "Body"})
  end
end)
```

DuckDB is optimized for analytical queries, so bulk inserts and complex aggregations should perform well.
