# Implementation Spec

## Platform

- Ubuntu 26.04 on WSL2.
- Windows 11 host.
- Clone and run from the Linux filesystem, preferably `~/.dotfiles`.

## Install Model

- Interactive by default.
- Non-interactive mode requires `--non-interactive`.
- `--dry-run` shows the resolved installation plan without mutating local files.
- `--no-doctor` skips final doctor checks after install/linking.
- Plain reruns reuse saved setup choices from `~/.config/dotfiles/` and skip onboarding prompts.
- `--reconfigure` asks setup questions again, showing saved choices as defaults.
- `--default-shell zsh|bash|unchanged` controls the login-shell change.
- Tool groups have user-facing descriptions and recommended defaults.
- Ubuntu base packages are an always-run dependency setup step, not a selectable tool group.
- Local identity and secrets are never committed or overwritten.
- Real installs persist `profile`, `selected-tools`, and `default-shell`; dry-runs do not.

## Tool Groups

| Group | Default | Purpose |
| --- | --- | --- |
| shell | recommended | zsh, Starship, zoxide, fzf, completions, suggestions, and highlighting |
| modern-cli | recommended | apt-installed ripgrep, fd, bat, eza, jq, yq, gh, tree, and tmux |
| runtime | recommended | mise-managed global Node, .NET, Python, Go, uv, and Java |
| history | optional | Atuin searchable shell history |
| corporate-ca | explicit rerun | Refresh TLS interception CA certificates when requested |

Dependency setup always runs first during real installs and installs Ubuntu
essentials for compiling, downloads, certificates, archives, locale, JSON,
Windows-browser launching, and mise-managed .NET native dependencies. Dry-runs show this step in the plan without installing packages or
writing state. Legacy saved `selected-tools` entries and `--with/--without
base` flags are accepted as no-ops and are not persisted.

CA refresh runs immediately after dependency setup during every real install,
before runtime, Docker, or other network-heavy setup. On WSL it can import
Windows-trusted CA certificates whose subjects match issuers from configured
download host certificate chains. Host-captured CA certificates still require a
local allowlist before installation.

Ubuntu apt owns WSL system tools and general CLIs, including Starship, Atuin,
zsh autosuggestions, and syntax highlighting. mise is installed from its
official Ubuntu 26.04 PPA and is reserved for global developer language
runtimes and project version switching for `node`, `dotnet`, `python`, `go`,
`uv`, and `java`. The managed defaults are `node@24.17.0`,
`dotnet@10.0.301`, `python@3.13.14`, `go@1.26.3`, `uv@0.11.21`, and
`java@21`. `zsh-completions` is the only Git-installed shell exception because
Ubuntu 26.04 does not package it.

Docker is not a tool group prompt. It is one mutually exclusive strategy:

- `wsl-engine`: recommended Docker Engine inside WSL.
- `desktop`: optional Docker Desktop WSL integration check.
- `none`: skip Docker setup.

Corporate CA support is available as an explicit rerun group, but the main
setup path refreshes CA trust immediately after base packages regardless of
profile.

`./setup verify` remains a diagnostic command. Reconfigure defaults come from
persisted setup state, not live command detection.

## Acceptance Checks

- `bash -n` passes for all shell scripts.
- `./setup help` works.
- `./setup verify` gives actionable warnings rather than crashing.
- Existing local files are preserved.
- Existing installs missing `default-shell` resolve to `unchanged` on plain rerun.
- Interactive prompts include labels, recommendation tags, and explanations.
- History is marked Optional in light blue and remains disabled by default.
- Existing Git identity values are displayed and preserved unless explicitly changed.
- `wslview` opens URLs with the default Windows browser through `explorer.exe`.
- Dry-run does not create profile, identity, links, templates, or backups.
- Corporate CA dry-run does not install certificates or update system trust.
- No-doctor install still prints the final Complete section.
- zsh startup resolves the installed repo root and loads aliases/modules from any checkout path.
- Bash and Zsh load shared configuration through marker-managed blocks in regular user rc files.
- `./scripts/test-docker.sh` passes on Docker with Ubuntu 26.04.
