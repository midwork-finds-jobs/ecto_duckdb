defmodule SamplePhoenix.Setup do
  @moduledoc """
  Setup script to initialize the DuckDB database.
  """

  alias SamplePhoenix.Repo

  def run do
    IO.puts("Setting up database...")

    # Start the application
    {:ok, _} = Application.ensure_all_started(:sample_phoenix)

    # Create schema_migrations table
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version BIGINT PRIMARY KEY,
      inserted_at TIMESTAMP NOT NULL
    )
    """)

    IO.puts("Schema migrations table created!")

    # Create sequence for posts
    Repo.query!("CREATE SEQUENCE IF NOT EXISTS posts_id_seq START 1")

    # Create posts table
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS posts (
      id INTEGER PRIMARY KEY DEFAULT nextval('posts_id_seq'),
      title TEXT,
      body TEXT,
      published INTEGER NOT NULL DEFAULT 0,
      inserted_at TIMESTAMP NOT NULL,
      updated_at TIMESTAMP NOT NULL
    )
    """)

    IO.puts("Posts table created!")

    # Insert migration version
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

    Repo.query!(
      "INSERT OR IGNORE INTO schema_migrations (version, inserted_at) VALUES (?, ?)",
      [20_251_027_193_450, timestamp]
    )

    IO.puts("Database setup complete!")
  end
end
