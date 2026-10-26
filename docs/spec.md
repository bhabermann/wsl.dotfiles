# Single-account implementation

- Windows 11 x64; Windows PowerShell 5.1 or PowerShell 7; install WSL 2 with elevation when needed.
- Pinned Debian 13 slim rootfs imported directly, without a Docker prerequisite.
- One normal Linux user and one Git identity. Passworded sudo remains after bootstrap.
- No work/personal state, corporate CA import, Ubuntu PPA, or Docker Desktop path.
- Minimal apt dependency sets, no recommended packages, and package/index cleanup.
- Systemd owns Docker/containerd lifecycle; distro startup is on demand.
- Windows per-user fonts, Terminal fragment, optional applications, and cached profile.
- Fast mise shims by default, explicit full activation available per platform.
- Registered distro location and saved ownership must agree on reruns.
- No global WSL shutdown, sign-in tasks, or changes to unrelated distros.
- Dry-run exits before downloads, writes, root provisioning, or app installation.
- Gather Windows and Linux choices and Git identity before provisioning; resume a saved plan once after a prerequisite restart.
- Completed Windows setup saves its choices only after verification; interrupted
  creation has an ownership record so provisioning can be resumed.
- Bash/zsh source blocks preserve user content; Windows JSONC editing preserves
  comments and unrelated settings. Modified user files receive adjacent backups.
- Optional app failures are reported; failed core preparation stops completion.
- Root/system setup uses temporary sudo permission with EXIT/INT/TERM cleanup.
- Tests isolate filesystem/registry writes and validate exact disposable-distro
  registration paths before destructive cleanup.

Public entrypoints are documented in README.md. This branch deliberately retires
--profile and replaces Ubuntu-only behavior instead of supporting multiple bases.
