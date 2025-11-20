defmodule EctoDuckdb.User do
  @moduledoc "Test schema for User"

  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:name, :string)
    field(:email, :string)
    field(:age, :integer)
    has_many(:posts, EctoDuckdb.Post)
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :age])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end
end

defmodule EctoDuckdb.Post do
  @moduledoc "Test schema for Post"

  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field(:title, :string)
    field(:body, :string)
    field(:published, :boolean, default: false)
    belongs_to(:user, EctoDuckdb.User)
    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :body, :published, :user_id])
    |> validate_required([:title])
  end
end
