defmodule EctoDuckdb.TestRepo do
  use Ecto.Repo,
    otp_app: :ecto_duckdb,
    adapter: Ecto.Adapters.DuckDB
end
