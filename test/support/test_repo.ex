defmodule EctoDuckdb.TestRepo do
  @moduledoc "Test repository for EctoDuckdb adapter tests"

  use Ecto.Repo,
    otp_app: :ecto_duckdb,
    adapter: Ecto.Adapters.DuckDB
end
