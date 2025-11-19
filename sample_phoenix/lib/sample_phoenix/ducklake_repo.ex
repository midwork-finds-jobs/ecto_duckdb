defmodule SamplePhoenix.DuckLakeRepo do
  use Ecto.Repo,
    otp_app: :sample_phoenix,
    adapter: Ecto.Adapters.DuckDBex

  # Enable raw multi-statement query support
  use Ecto.Adapters.DuckDBex.RawQuery
end
