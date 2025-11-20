defmodule SamplePhoenix.Demo do
  @moduledoc """
  Demo module to test DuckDB with Phoenix.
  """

  alias SamplePhoenix.{Repo, Blog.Post}
  import Ecto.Query

  def run do
    IO.puts("\n=== Phoenix + DuckDB Demo ===\n")

    # Create some sample posts
    IO.puts("Creating sample posts...")

    {:ok, _post1} =
      create_post("Hello DuckDB!", "This is our first post using DuckDB with Phoenix", true)

    {:ok, _post2} = create_post("Phoenix Integration", "DuckDB works great with Phoenix!", true)
    {:ok, post3} = create_post("Draft Post", "This post is not published yet", false)

    IO.puts("Created 3 posts")

    # List all posts
    IO.puts("\n--- All Posts ---")
    posts = Repo.all(Post)

    Enum.each(posts, fn post ->
      status = if post.published, do: "published", else: "draft"
      IO.puts("  [#{status}] #{post.title}")
    end)

    # Query published posts only
    IO.puts("\n--- Published Posts ---")
    published = Repo.all(from(p in Post, where: p.published == true))

    Enum.each(published, fn post ->
      IO.puts("  #{post.title}: #{post.body}")
    end)

    # Update a post
    IO.puts("\n--- Publishing draft post ---")

    post3
    |> Post.changeset(%{published: true})
    |> Repo.update!()

    count = Repo.aggregate(Post, :count, :id)
    IO.puts("\n--- Total posts: #{count} (all published now) ---")

    IO.puts("\n=== Demo Complete ===\n")
  end

  defp create_post(title, body, published) do
    %Post{}
    |> Post.changeset(%{
      title: title,
      body: body,
      published: published
    })
    |> Repo.insert()
  end
end
