defmodule SamplePhoenix.DuckLakeRepo do
  use Ecto.Repo,
    otp_app: :sample_phoenix,
    adapter: Ecto.Adapters.DuckDBex
end
