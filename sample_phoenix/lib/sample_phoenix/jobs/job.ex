defmodule SamplePhoenix.Jobs.Job do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "jobs" do
    field :url, :string
    # Note: DuckLake doesn't support timestamps with default values
    # https://github.com/duckdb/ducklake/issues/297
  end

  @doc false
  def changeset(job, attrs) do
    job
    |> cast(attrs, [:url])
    |> validate_required([:url])
  end
end
