defmodule SamplePhoenix.Repo do
  use Ecto.Repo,
    otp_app: :sample_phoenix,
    adapter: Ecto.Adapters.DuckDBex
end
