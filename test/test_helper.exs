ExUnit.start()

# Clean up any existing test database
test_db = "test/test.duckdb"
File.rm(test_db)
File.rm(test_db <> ".wal")

# Create test database
_ = Ecto.Adapters.DuckDBex.storage_up(EctoDuckdbex.TestRepo.config())

# Start the repo
{:ok, _pid} = EctoDuckdbex.TestRepo.start_link()

# Run migrations
Ecto.Migrator.run(EctoDuckdbex.TestRepo, [{0, EctoDuckdbex.TestMigration}], :up, all: true, log: false)
