# Validation — 2026-10-26

Tested on Windows 11 x64, WSL 2.7.13, Windows PowerShell 5.1 and PowerShell 7.6.9.

| Check | Result |
| --- | --- |
| Linux fixtures: reruns, dry-run, identity, tool choices | Passed |
| Debian container build and fixture suite | Passed |
| Disposable WSL import from checksum-pinned rootfs | Passed |
| systemd boot, Docker Engine, Compose, Buildx | Passed |
| Cold-start daemon readiness | 4.77 seconds |
| Windows build context and project directory containing spaces | Passed |
| Windows bind mounts and Compose execution | Passed |
| PowerShell 5.1/7 quotes, empty arguments, stdin, mounts, exit codes | Passed |
| cmd launcher and nonzero exit codes | Passed |
| Windows profile/Terminal fixtures and repeated configuration | Passed |
| Four font faces using scratch files/HKCU key | Passed without elevation |
| Official portable zoxide download and cached initialization | Passed |
| Recommended Debian tools plus mise-managed uv 0.11.21 | Passed |

The compressed rootfs is 28.46 MiB. The core installation measured **644.8 MiB**
as the sum of /usr, /var, /home, and /etc before downloading container images.
This is filesystem usage, not the allocated Windows VHD size.

Warm zsh startup measured a median of **87 ms** over ten launches of the minimal
environment. A separate run with recommended CLIs and uv measured roughly 88 ms.
fzf Ctrl-R bindings and runtime shims were checked explicitly.

A PowerShell 7 fixture with cached zoxide, Starship, and mise shims measured
**1,157 ms** to launch and load the profile, versus **485 ms** with -NoProfile
(672 ms additional time). Measurements used a terminal and ten warm runs after
discarding the first run. They include host/module initialization and are specific
to this machine, rather than a cross-machine startup guarantee.

The daily-use Windows installer was deliberately not run. Windows app
choices were exercised through planning/fixtures and a portable zoxide download;
GUI app installers and every optional language runtime were not installed.
The interactive Linux password prompt is left to first provisioning; test users
were disposable locked accounts with provisioning-only sudo permission.

Tests used temporary Terminal/profile files and a scratch font registry key.
Disposable distros were removed, and daily-use defaults/profiles were preserved.
