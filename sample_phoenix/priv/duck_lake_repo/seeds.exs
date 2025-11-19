# Script for populating the DuckLake database. You can run it as:
#
#     mix run priv/duck_lake_repo/seeds.exs
#
# This seed file loads Lever job board URLs from Common Crawl into the jobs table
#
# Note: Extensions (httpfs, netquack) are installed and loaded automatically
# via the :extensions config option in config/dev.exs

alias SamplePhoenix.DuckLakeRepo

IO.puts("Fetching job URLs from Common Crawl and inserting into DuckLake...")
IO.puts("This may take a minute as it queries remote data sources...")

# Note: Using exec! for multi-statement WITH clause query
# DuckLake doesn't yet support macros so we can't DRY the 2 queries here yet
DuckLakeRepo.exec!("""
  WITH eu_jobs AS (
    SELECT DISTINCT('https://' || extract_host(url) || extract_path(url)) as url
    FROM read_json(
        format(
          'https://index.commoncrawl.org/CC-MAIN-2025-43-index?url={}&output=json',
          url_encode('https://jobs.eu.lever.co/*')
        )
    )
  ), non_eu_jobs AS (
    SELECT DISTINCT('https://' || extract_host(url) || extract_path(url)) as url
    FROM read_json(
        format(
          'https://index.commoncrawl.org/CC-MAIN-2025-43-index?url={}&output=json',
          url_encode('https://jobs.lever.co/*')
        )
    )
  )
  MERGE INTO jobs
    USING (
        FROM eu_jobs
        UNION ALL
        FROM non_eu_jobs
    ) AS upserts
    ON (upserts.url = jobs.url)
    WHEN NOT MATCHED THEN INSERT;
""")

{:ok, count_result} = DuckLakeRepo.query("SELECT COUNT(*) as count FROM jobs")
[[count]] = count_result.rows
IO.puts("✅ Seeding complete! #{count} total job URLs in DuckLake database.")
