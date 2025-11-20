ExUnit.start()

# Start the repo (in-memory database, no cleanup needed)
{:ok, _pid} = EctoDuckdb.TestRepo.start_link()

# Run migrations
Ecto.Migrator.run(EctoDuckdb.TestRepo, [{0, EctoDuckdb.TestMigration}], :up,
  all: true,
  log: false
)
