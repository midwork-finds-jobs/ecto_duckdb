import Config

if Mix.env() == :test do
  config :ecto_duckdb, EctoDuckdb.TestRepo,
    adapter: Ecto.Adapters.DuckDB,
    database: "test/test.duckdb",
    pool_size: 1,
    log: false
end
