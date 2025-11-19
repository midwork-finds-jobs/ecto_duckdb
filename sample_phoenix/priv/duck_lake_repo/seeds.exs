# Script for populating the DuckLake database. You can run it as:
#
#     mix run priv/duck_lake_repo/seeds.exs
#
# This seed file loads Lever job board URLs from Common Crawl into the jobs table

alias SamplePhoenix.DuckLakeRepo

IO.puts("Installing extensions...")
DuckLakeRepo.query!("INSTALL httpfs")
DuckLakeRepo.query!("LOAD httpfs")
DuckLakeRepo.query!("INSTALL netquack FROM community")
DuckLakeRepo.query!("LOAD netquack")

IO.puts("Fetching job URLs from Common Crawl and inserting into DuckLake...")
IO.puts("This may take a minute as it queries remote data sources...")

# TODO: DuckLake doesn't yet support macros so we can't DRY these queries
# Split into two separate MERGE queries to avoid multi-statement issues
DuckLakeRepo.query!("""
  MERGE INTO jobs
    USING (
      SELECT DISTINCT('https://' || extract_host(url) || extract_path(url)) as url
      FROM read_json(
          format(
            'https://index.commoncrawl.org/CC-MAIN-2025-43-index?url={}&output=json',
            url_encode('https://jobs.eu.lever.co/*')
          )
      )
    ) AS eu_jobs
    ON (eu_jobs.url = jobs.url)
    WHEN NOT MATCHED THEN INSERT
""")

DuckLakeRepo.query!("""
  MERGE INTO jobs
    USING (
      SELECT DISTINCT('https://' || extract_host(url) || extract_path(url)) as url
      FROM read_json(
          format(
            'https://index.commoncrawl.org/CC-MAIN-2025-43-index?url={}&output=json',
            url_encode('https://jobs.lever.co/*')
          )
      )
    ) AS non_eu_jobs
    ON (non_eu_jobs.url = jobs.url)
    WHEN NOT MATCHED THEN INSERT
""")

{:ok, count_result} = DuckLakeRepo.query("SELECT COUNT(*) as count FROM jobs")
[[count]] = count_result.rows
IO.puts("✅ Seeding complete! Inserted #{count} job URLs into DuckLake database.")
