import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :sample_phoenix, SamplePhoenix.Repo,
  database: Path.expand("../sample_phoenix_test.duckdb", __DIR__),
  # DuckDB only allows one writer at a time
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox

# Configure DuckLake database for test
# For testing, use a simple DuckDB database without ducklake features
config :sample_phoenix, SamplePhoenix.DuckLakeRepo,
  database: Path.expand("../sample_phoenix_test_ducklake.duckdb", __DIR__),
  # DuckDB only allows one writer at a time
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :sample_phoenix, SamplePhoenixWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "DxNIIui+PJZ4pTw6jTZjlfBC61OL1eNkBUd+AptAH5iwZ9lyXmTmSQQRImqZGm1Y",
  server: false

# In test we don't send emails
config :sample_phoenix, SamplePhoenix.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
