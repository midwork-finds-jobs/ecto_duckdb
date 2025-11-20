defmodule EctoDuckDB.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ecto_duckdb,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/midwork-finds-jobs/ecto_duckdb",
      homepage_url: "https://github.com/midwork-finds-jobs/ecto_duckdb",
      deps: deps(),
      description: description(),
      elixirc_options: [warnings_as_errors: true],
      elixirc_paths: elixirc_paths(Mix.env()),

      # Docs
      name: "Ecto DuckDB",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:decimal, "~> 1.6 or ~> 2.0"},
      {:ecto_sql, "~> 3.13.0"},
      {:ecto, "~> 3.13.0"},
      {:db_connection, "~> 2.8"},
      {:duckdbex, "~> 0.3.5"},
      {:ex_doc, "~> 0.27", only: [:dev], runtime: false},
      {:jason, ">= 0.0.0", only: [:dev, :test, :docs]},
      {:credo, "~> 1.6", only: [:dev, :test, :docs]},
      {:dialyxir, ">= 0.0.0", only: [:dev], runtime: false}
    ]
  end

  defp description do
    "A DuckDB Ecto3 adapter using duckdbex."
  end

  defp docs do
    [
      main: "Ecto.Adapters.DuckDB",
      source_ref: "v#{@version}",
      source_url: "https://github.com/midwork-finds-jobs/ecto_duckdb"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
