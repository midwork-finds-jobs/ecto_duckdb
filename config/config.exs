import Config

if Mix.env() == :test do
  config :ecto_duckdbex, EctoDuckdbex.TestRepo,
    adapter: Ecto.Adapters.DuckDBex,
    database: "test/test.duckdb",
    pool_size: 1,
    log: false
end
