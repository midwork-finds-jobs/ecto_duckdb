defmodule SamplePhoenix.SetupDucklake do
  @moduledoc """
  Setup module for installing DuckLake extensions and configuring WebDAV access.

  Run this once before starting the application:

      mix run -e "SamplePhoenix.SetupDucklake.install_extensions()"

  Or include it in your application startup for automatic installation.
  """

  require Logger

  @doc """
  Install required DuckDB extensions for DuckLake and WebDAV support.

  Note: webdavfs must be installed from the community repository and is
  only available on Linux (x86_64/ARM64). It will be skipped on macOS/Windows.
  """
  def install_extensions(opts \\ []) do
    Logger.info("Installing DuckDB extensions for DuckLake and WebDAV...")

    database_path = Path.expand("../sample_phoenix_dev.duckdb", __DIR__)
    skip_webdavfs = Keyword.get(opts, :skip_webdavfs, false)

    # Install ducklake (always available)
    case Duckex.install_extensions([:ducklake], database: database_path) do
      :ok ->
        Logger.info("✓ ducklake extension installed")

      {:error, error} ->
        Logger.error("Failed to install ducklake: #{inspect(error)}")
        {:error, error}
    end

    # Try to install webdavfs (may not be available on all platforms)
    unless skip_webdavfs do
      case Duckex.install_extensions([{:webdavfs, source: :community}], database: database_path) do
        :ok ->
          Logger.info("✓ webdavfs extension installed (for remote WebDAV storage)")
          :ok

        {:error, error} ->
          error_msg = inspect(error)

          if String.contains?(error_msg, "HTTP 404") or String.contains?(error_msg, "osx_arm64") do
            Logger.warning("""
            ⚠ webdavfs extension not available for your platform (macOS ARM64)
            This is expected - webdavfs is only available on Linux.
            You can use local DuckLake storage for development.
            """)

            :ok
          else
            Logger.error("Failed to install webdavfs: #{error_msg}")
            {:error, error}
          end
      end
    else
      Logger.info("⊘ Skipping webdavfs installation (not needed for local development)")
      :ok
    end
  end

  @doc """
  Check if required extensions are installed.
  """
  def check_extensions do
    database_path = Path.expand("../sample_phoenix_dev.duckdb", __DIR__)

    with {:ok, conn} <- Duckex.start_link(database: database_path),
         {:ok, result} <- Duckex.query(conn, "SELECT extension_name FROM duckdb_extensions() WHERE installed = true") do
      installed = result.rows |> Enum.map(&List.first/1) |> MapSet.new()

      required = MapSet.new(["ducklake", "webdavfs"])
      missing = MapSet.difference(required, installed)

      Process.exit(conn, :normal)

      if MapSet.size(missing) == 0 do
        Logger.info("✓ All required extensions are installed")
        :ok
      else
        Logger.warning("Missing extensions: #{inspect(MapSet.to_list(missing))}")
        {:error, :missing_extensions, MapSet.to_list(missing)}
      end
    end
  end
end
