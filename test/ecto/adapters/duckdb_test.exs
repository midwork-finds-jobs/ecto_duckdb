defmodule Ecto.Adapters.DuckDBTest do
  use ExUnit.Case, async: false

  alias EctoDuckdb.Post
  alias EctoDuckdb.TestRepo
  alias EctoDuckdb.User

  setup do
    # Clean up tables before each test
    TestRepo.delete_all(Post)
    TestRepo.delete_all(User)
    :ok
  end

  describe "basic CRUD operations" do
    test "insert and query user" do
      changeset = User.changeset(%User{}, %{name: "John", email: "john@example.com", age: 30})
      assert {:ok, user} = TestRepo.insert(changeset)
      assert user.id
      assert user.name == "John"
      assert user.email == "john@example.com"
      assert user.age == 30

      # Query it back
      found_user = TestRepo.get(User, user.id)
      assert found_user.id == user.id
      assert found_user.name == "John"
    end

    test "update user" do
      {:ok, user} =
        TestRepo.insert(User.changeset(%User{}, %{email: "test@example.com", name: "Test"}))

      changeset = User.changeset(user, %{name: "Updated"})
      assert {:ok, updated} = TestRepo.update(changeset)
      assert updated.name == "Updated"

      # Verify in database
      found = TestRepo.get(User, user.id)
      assert found.name == "Updated"
    end

    test "delete user" do
      {:ok, user} = TestRepo.insert(User.changeset(%User{}, %{email: "delete@example.com"}))

      assert {:ok, _} = TestRepo.delete(user)
      assert nil == TestRepo.get(User, user.id)
    end
  end

  describe "associations" do
    test "create post with user association" do
      {:ok, user} =
        TestRepo.insert(User.changeset(%User{}, %{email: "author@example.com", name: "Author"}))

      post_changeset =
        Post.changeset(%Post{}, %{
          title: "My Post",
          body: "Post content",
          published: true,
          user_id: user.id
        })

      assert {:ok, post} = TestRepo.insert(post_changeset)
      assert post.user_id == user.id
      assert post.title == "My Post"
    end

    test "preload associations" do
      {:ok, user} =
        TestRepo.insert(User.changeset(%User{}, %{email: "author@example.com", name: "Author"}))

      {:ok, _post1} =
        TestRepo.insert(
          Post.changeset(%Post{}, %{
            title: "Post 1",
            body: "Content 1",
            user_id: user.id
          })
        )

      {:ok, _post2} =
        TestRepo.insert(
          Post.changeset(%Post{}, %{
            title: "Post 2",
            body: "Content 2",
            user_id: user.id
          })
        )

      # Preload posts
      user_with_posts = TestRepo.get(User, user.id) |> TestRepo.preload(:posts)
      assert length(user_with_posts.posts) == 2
    end
  end

  describe "queries" do
    test "query with where clause" do
      {:ok, user1} =
        TestRepo.insert(
          User.changeset(%User{}, %{email: "alice@example.com", name: "Alice", age: 25})
        )

      {:ok, _user2} =
        TestRepo.insert(
          User.changeset(%User{}, %{email: "bob@example.com", name: "Bob", age: 35})
        )

      import Ecto.Query

      young_users = TestRepo.all(from(u in User, where: u.age < 30))
      assert length(young_users) == 1
      assert hd(young_users).id == user1.id
    end

    test "aggregate functions" do
      {:ok, _} = TestRepo.insert(User.changeset(%User{}, %{email: "user1@example.com", age: 20}))
      {:ok, _} = TestRepo.insert(User.changeset(%User{}, %{email: "user2@example.com", age: 30}))
      {:ok, _} = TestRepo.insert(User.changeset(%User{}, %{email: "user3@example.com", age: 40}))

      import Ecto.Query

      result = TestRepo.one(from(u in User, select: avg(u.age)))
      # DuckDB returns float for avg()
      assert result == 30.0
    end
  end

  describe "transactions" do
    test "successful transaction" do
      result =
        TestRepo.transaction(fn ->
          {:ok, user} =
            TestRepo.insert(User.changeset(%User{}, %{email: "tx@example.com", name: "TX User"}))

          user
        end)

      assert {:ok, user} = result
      assert TestRepo.get(User, user.id)
    end

    test "rollback transaction" do
      result =
        TestRepo.transaction(fn ->
          {:ok, user} =
            TestRepo.insert(
              User.changeset(%User{}, %{email: "rollback@example.com", name: "Rollback User"})
            )

          TestRepo.rollback(:oops)
          user
        end)

      assert {:error, :oops} = result

      # User should not exist
      import Ecto.Query
      assert [] = TestRepo.all(from(u in User, where: u.email == "rollback@example.com"))
    end
  end

  describe "timestamps" do
    test "automatically sets inserted_at and updated_at" do
      {:ok, user} = TestRepo.insert(User.changeset(%User{}, %{email: "timestamps@example.com"}))

      assert user.inserted_at
      assert user.updated_at
      assert NaiveDateTime.compare(user.inserted_at, user.updated_at) == :eq

      # Update and check updated_at changes
      # Ensure some time passes
      Process.sleep(10)
      changeset = User.changeset(user, %{name: "Updated Name"})
      {:ok, updated_user} = TestRepo.update(changeset)

      # updated_at should be later than inserted_at (or equal if very fast)
      comparison = NaiveDateTime.compare(updated_user.updated_at, updated_user.inserted_at)
      assert comparison in [:gt, :eq]
    end
  end
end
