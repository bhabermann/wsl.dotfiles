# Implementation Spec

## Platform

- Ubuntu 24.04 on WSL2.
- Windows 11 host.
- Clone and run from the Linux filesystem, preferably `~/.dotfiles`.

## Install Model

- Interactive by default.
- Non-interactive mode requires `--non-interactive`.
- `--dry-run` shows the resolved installation plan without mutating local files.
- `--no-doctor` skips final doctor checks after install/linking.
- Tool groups have user-facing descriptions and recommended defaults.
- Local identity and secrets are never committed or overwritten.

## Tool Groups

| Group | Default | Purpose |
| --- | --- | --- |
| base | recommended | Ubuntu essentials for compiling, downloads, certificates, archives, locale, and JSON handling |
| shell | recommended | zsh, Starship, zoxide, fzf, completions, suggestions, and highlighting |
| modern-cli | recommended | ripgrep, fd, bat, eza, jq, yq, tree, and tmux |
| runtime | recommended | mise-managed Node, Python, Java, .NET, and Go |
| history | optional | Atuin searchable shell history |

Docker is not a tool group prompt. It is one mutually exclusive strategy:

- `desktop`: recommended Docker Desktop WSL integration check.
- `wsl-engine`: Docker Engine inside WSL.
- `none`: skip Docker setup.

## Acceptance Checks

- `bash -n` passes for all shell scripts.
- `./setup help` works.
- `./setup verify` gives actionable warnings rather than crashing.
- Existing local files are preserved.
- Interactive prompts include labels, recommendation tags, and explanations.
- Dry-run does not create profile, identity, links, templates, or backups.
- No-doctor install still prints the final Complete section.
- `./scripts/test-docker.sh` passes on Docker with Ubuntu 24.04.
