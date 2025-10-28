defmodule EctoDuckDB.Schemas.Account do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias EctoDuckDB.Schemas.Product
  alias EctoDuckDB.Schemas.User

  schema "accounts" do
    field(:name, :string)
    field(:email, :string)

    timestamps()

    many_to_many(:users, User, join_through: "account_users")
    has_many(:products, Product)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
