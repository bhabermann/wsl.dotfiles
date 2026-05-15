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
- Plain reruns reuse saved setup choices from `~/.config/dotfiles/` and skip onboarding prompts.
- `--reconfigure` asks setup questions again, showing saved choices as defaults.
- `--default-shell zsh|unchanged` controls whether install attempts to make zsh the login shell.
- Tool groups have user-facing descriptions and recommended defaults.
- Ubuntu base packages are an always-run dependency setup step, not a selectable tool group.
- Local identity and secrets are never committed or overwritten.
- Real installs persist `profile`, `selected-tools`, and `default-shell`; dry-runs do not.

## Tool Groups

| Group | Default | Purpose |
| --- | --- | --- |
| shell | recommended | zsh, Starship, zoxide, fzf, completions, suggestions, and highlighting |
| modern-cli | recommended | apt-installed ripgrep, fd, bat, eza, jq, yq, gh, tree, and tmux |
| runtime | recommended | mise-managed global Node, Python, Java, .NET, and Go |
| history | optional | Atuin searchable shell history |
| corporate-ca | explicit work opt-in | Capture configured corporate TLS interception CA chains and install only allowlisted CA certificates |

Dependency setup always runs first during real installs and installs Ubuntu
essentials for compiling, downloads, certificates, archives, locale, and JSON
handling. Dry-runs show this step in the plan without installing packages or
writing state. Legacy saved `selected-tools` entries and `--with/--without
base` flags are accepted as no-ops and are not persisted.

Ubuntu apt owns WSL system tools and general CLIs. mise is reserved for global
developer language runtimes and project version switching for `node`, `python`,
`java`, `dotnet`, and `go`. Atuin is the only optional non-language mise
exception because it is not available through standard Ubuntu 24.04 apt sources.

Docker is not a tool group prompt. It is one mutually exclusive strategy:

- `desktop`: recommended Docker Desktop WSL integration check.
- `wsl-engine`: Docker Engine inside WSL.
- `none`: skip Docker setup.

Corporate CA support is never selected by presets. Interactive installs only ask
for it as a work-profile follow-up, defaulting to no. Non-interactive installs
must pass `--with corporate-ca`.

`./setup verify` remains a diagnostic command. Reconfigure defaults come from
persisted setup state, not live command detection.

## Acceptance Checks

- `bash -n` passes for all shell scripts.
- `./setup help` works.
- `./setup verify` gives actionable warnings rather than crashing.
- Existing local files are preserved.
- Existing installs missing `default-shell` resolve to `unchanged` on plain rerun.
- Interactive prompts include labels, recommendation tags, and explanations.
- Dry-run does not create profile, identity, links, templates, or backups.
- Corporate CA dry-run does not install certificates or update system trust.
- No-doctor install still prints the final Complete section.
- zsh startup resolves the installed repo root and loads aliases/modules from any checkout path.
- `./scripts/test-docker.sh` passes on Docker with Ubuntu 24.04.
