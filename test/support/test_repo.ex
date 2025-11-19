defmodule EctoDuckdbex.TestRepo do
  use Ecto.Repo,
    otp_app: :ecto_duckdbex,
    adapter: Ecto.Adapters.DuckDBex
end
