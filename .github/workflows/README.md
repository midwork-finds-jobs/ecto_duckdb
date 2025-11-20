# GitHub Actions CI/CD

This directory contains GitHub Actions workflows for continuous integration and testing.

## Workflows

### CI Workflow (`ci.yml`)

The main CI workflow runs on every push to `main` and on all pull requests. It consists of two jobs:

#### 1. Test & Lint Job

This job verifies code quality and runs the test suite:

- **Code Formatting**: Checks that all code is properly formatted with `mix format`
- **Linting**: Runs Credo in two modes:
  - Suggest mode (non-blocking): Shows all suggestions
  - Strict mode (warnings only): Enforces strict checks without failing the build
- **Compilation**: Compiles the project with warnings treated as errors
- **Tests**: Runs the full test suite

#### 2. Sample Phoenix - Migrations Job

This job verifies that migrations work correctly in the sample Phoenix application:

- **Migration Execution**: Runs `mix ecto.migrate` with `--pool-size 1`
- **Reversibility Check**: Ensures migrations can be rolled back and re-run
- **Idempotency Check**: Verifies that running migrations again shows "already up"

## Environment Configuration

The workflow uses:

- **Elixir Version**: 1.15
- **OTP Version**: 26
- **Mix Environment**: test

These can be updated in the `env` section of the workflow file.

## Caching

Dependencies and build artifacts are cached to speed up CI runs:

- Root project: `deps/` and `_build/`
- Sample Phoenix: `sample_phoenix/deps/` and `sample_phoenix/_build/`

Cache keys are based on the `mix.lock` file, so they automatically invalidate when dependencies change.

## Local Testing

You can run the same checks locally before pushing:

```bash
# Format check
mix format --check-formatted

# Linting
mix credo suggest --all
mix credo --strict --mute-exit-status

# Compilation
mix compile --warnings-as-errors

# Tests
mix test

# Sample Phoenix migrations
cd sample_phoenix
mix ecto.migrate --pool-size 1
mix ecto.rollback --all --pool-size 1
mix ecto.migrate --pool-size 1
```

## Troubleshooting

### Failed Formatting Check

Run `mix format` to auto-format all files, then commit the changes.

### Failed Credo Check

Review the Credo output and fix issues. Use `mix credo explain <check>` for details.

### Failed Migration

Ensure migrations work with `--pool-size 1` as DuckDB only supports one writer at a time.

### Cache Issues

If you suspect cache corruption, you can clear caches by:

1. Going to Actions → Caches in GitHub
2. Deleting the relevant cache entries
