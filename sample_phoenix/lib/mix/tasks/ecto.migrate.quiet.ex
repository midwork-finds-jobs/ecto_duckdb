defmodule Mix.Tasks.Ecto.Migrate.Quiet do
  @moduledoc """
  Runs migrations with reduced logging output.

  Usage:
      mix ecto.migrate.quiet

  To enable debug logs, use:
      DEBUG=1 mix ecto.migrate.quiet
  """

  use Mix.Task

  @shortdoc "Runs database migrations with minimal logging"

  def run(args) do
    # Configure logger based on DEBUG environment variable
    level = if System.get_env("DEBUG") in ["1", "true"], do: :debug, else: :info
    Logger.configure(level: level)

    # Run the actual ecto.migrate task
    Mix.Task.run("ecto.migrate", args)
  end
end
