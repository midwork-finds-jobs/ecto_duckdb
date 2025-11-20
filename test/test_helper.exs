ExUnit.start()

# Clean up any existing test database
test_db = "test/test.duckdb"
File.rm(test_db)
File.rm(test_db <> ".wal")

# Create test database
_ = Ecto.Adapters.DuckDB.storage_up(EctoDuckdb.TestRepo.config())

# Start the repo
{:ok, _pid} = EctoDuckdb.TestRepo.start_link()

# Run migrations
Ecto.Migrator.run(EctoDuckdb.TestRepo, [{0, EctoDuckdb.TestMigration}], :up,
  all: true,
  log: false
)
