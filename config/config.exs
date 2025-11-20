import Config

if Mix.env() == :test do
  config :ecto_duckdb, EctoDuckdb.TestRepo,
    adapter: Ecto.Adapters.DuckDB,
    database: :memory,
    pool_size: 1,
    log: false
end
