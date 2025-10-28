defmodule EctoDuckDB.Schemas.Schema2 do
  @moduledoc false

  use Ecto.Schema

  schema "schema2" do
    belongs_to(:post, EctoDuckDB.Schemas.Schema,
      references: :x,
      foreign_key: :z
    )
  end
end
