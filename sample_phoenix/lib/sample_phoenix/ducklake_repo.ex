defmodule SamplePhoenix.DuckLakeRepo do
  @moduledoc "DuckLake repository for remote storage with WebDAV"

  use Ecto.Repo,
    otp_app: :sample_phoenix,
    adapter: Ecto.Adapters.DuckDB

  # Enable raw multi-statement query support
  use Ecto.Adapters.DuckDB.RawQuery
end
