defmodule SamplePhoenix.Jobs.LeverLoader do
  @moduledoc """
  Loads Lever job board URLs from Common Crawl into the jobs table.

  This module uses DuckDB's httpfs and netquack extensions to query
  the Common Crawl index for Lever job posting URLs.
  """

  alias SamplePhoenix.{DuckLakeRepo, Jobs, Jobs.Job}

  @doc """
  Loads Lever job URLs from Common Crawl and inserts them into the jobs table.

  Options:
  - `:cc_index` - Common Crawl index to use (default: "CC-MAIN-2025-43")
  - `:clear_existing` - Whether to clear existing jobs before inserting (default: true)
  - `:patterns` - List of URL patterns to search for (default: lever.co job URLs)

  ## Examples

      iex> SamplePhoenix.Jobs.LeverLoader.load()
      {:ok, 1234}

      iex> SamplePhoenix.Jobs.LeverLoader.load(cc_index: "CC-MAIN-2024-50")
      {:ok, 1456}

      iex> SamplePhoenix.Jobs.LeverLoader.load(clear_existing: false)
      {:ok, 789}
  """
  def load(opts \\ []) do
    cc_index = Keyword.get(opts, :cc_index, "CC-MAIN-2025-43")
    clear_existing = Keyword.get(opts, :clear_existing, true)

    patterns =
      Keyword.get(opts, :patterns, [
        "https://jobs.lever.co/*",
        "https://jobs.eu.lever.co/*"
      ])

    IO.puts("\n=== Loading Lever Job URLs from Common Crawl ===\n")

    # Install and load extensions
    setup_extensions()

    # Create the macro
    create_common_crawl_macro(cc_index)

    # Query for URLs
    urls = fetch_urls(patterns)

    IO.puts("✅ Found #{length(urls)} unique Lever job URLs\n")

    # Clear existing if requested
    if clear_existing do
      clear_jobs()
    end

    # Insert jobs
    count = insert_jobs(urls)

    IO.puts("✅ Successfully inserted #{count} job URLs\n")

    # Show samples
    show_samples(urls)

    {:ok, count}
  rescue
    error ->
      IO.puts("\n❌ Error loading Lever URLs: #{inspect(error)}\n")
      {:error, error}
  end

  @doc """
  Fetches Lever job URLs from Common Crawl without inserting them.

  Returns `{:ok, urls}` where urls is a list of URL strings.
  """
  def fetch_lever_urls(opts \\ []) do
    cc_index = Keyword.get(opts, :cc_index, "CC-MAIN-2025-43")

    patterns =
      Keyword.get(opts, :patterns, [
        "https://jobs.lever.co/*",
        "https://jobs.eu.lever.co/*"
      ])

    setup_extensions()
    create_common_crawl_macro(cc_index)
    urls = fetch_urls(patterns)

    {:ok, urls}
  rescue
    error ->
      {:error, error}
  end

  # Private functions

  defp setup_extensions do
    IO.puts("📦 Installing DuckDB extensions...")

    DuckLakeRepo.query!("INSTALL httpfs")
    DuckLakeRepo.query!("LOAD httpfs")
    DuckLakeRepo.query!("INSTALL netquack FROM community")
    DuckLakeRepo.query!("LOAD netquack")

    IO.puts("✅ Extensions loaded\n")
  end

  defp create_common_crawl_macro(cc_index) do
    IO.puts("🔧 Creating common_crawl macro...")

    DuckLakeRepo.query!("""
    CREATE OR REPLACE MACRO common_crawl(search_url, cc_index := '#{cc_index}') AS TABLE
        SELECT DISTINCT('https://' || extract_host(url) || extract_path(url)) as url
        FROM read_json(
            format(
                'https://index.commoncrawl.org/{}-index?url={}&output=json',
                cc_index,
                url_encode(search_url)
            )
        )
    """)

    IO.puts("✅ Macro created\n")
  end

  defp fetch_urls(patterns) do
    IO.puts("🔍 Querying Common Crawl for Lever job URLs...")
    IO.puts("   Patterns: #{inspect(patterns)}")
    IO.puts("   This may take a minute...\n")

    # Build UNION ALL query for all patterns
    queries =
      Enum.map(patterns, fn pattern ->
        "SELECT url FROM common_crawl('#{pattern}')"
      end)

    sql = Enum.join(queries, "\nUNION ALL\n")

    result = DuckLakeRepo.query!(sql)

    Enum.map(result.rows, fn [url] -> url end)
  end

  defp clear_jobs do
    IO.puts("🗑️  Clearing existing jobs...")
    {deleted_count, _} = DuckLakeRepo.delete_all(Job)
    IO.puts("✅ Deleted #{deleted_count} existing jobs\n")
  end

  defp insert_jobs(urls) do
    IO.puts("💾 Inserting #{length(urls)} job URLs...")

    Enum.each(urls, fn url ->
      case Jobs.create_job(%{url: url}) do
        {:ok, _job} ->
          :ok

        {:error, changeset} ->
          IO.puts("⚠️  Failed to insert #{url}: #{inspect(changeset.errors)}")
      end
    end)

    length(urls)
  end

  defp show_samples(urls) do
    IO.puts("📋 Sample URLs:")

    Enum.take(urls, 5)
    |> Enum.each(fn url ->
      IO.puts("   - #{url}")
    end)

    if length(urls) > 5 do
      IO.puts("   ... and #{length(urls) - 5} more")
    end

    IO.puts("\n=== Load Complete ===\n")
  end
end
