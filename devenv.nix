{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  # https://devenv.sh/packages/
  packages = [ pkgs.git ];

  # https://devenv.sh/languages/
  languages.elixir.enable = true;

  # https://devenv.sh/git-hooks/
  git-hooks.hooks = {
    # Elixir files
    mix-format = {
      enable = true;
      name = "mix format";
      entry = "mix format --check-formatted";
      files = "\\.(ex|exs|heex)$";
    };
    credo = {
      enable = true;
      name = "mix credo";
      entry = "mix credo";
      files = "\\.(ex|exs|heex)$";
    };
    mix-test = {
      enable = true;
      name = "mix test";
      entry = "mix test";
      files = "\\.(ex|exs|heex)$";
    };
    # Nix files
    nixfmt-rfc-style.enable = true;
    # Github Actions
    actionlint.enable = true;
    # Markdown files
    markdownlint = {
      enable = true;
      settings.configuration = {
        # Ignore line lengths for now
        MD013 = false;
        # Allow inline html as it is used in phoenix default AGENTS.md
        MD033 = false;
      };
    };
    # Leaking secrets
    ripsecrets.enable = true;

    trufflehog.enable = true;
  };
}
