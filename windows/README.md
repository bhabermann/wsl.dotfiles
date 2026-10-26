# Windows setup

This branch creates a single-account Debian 13 WSL environment. Run the Windows
bootstrap from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1
```

WSL 2 must already be enabled. Windows setup runs per user without elevation;
Linux system provisioning uses the root access available to the distro owner.
The installer offers individual Windows apps and optional PowerShell integrations
for zoxide, Starship, and mise. It also prepares a per-user Nerd Font, a themed
Terminal profile, and Docker commands targeting the new distro.

See the [main README](../README.md) for the supported options, saved settings,
Docker bridge behavior, and test commands. Use -DryRun -NonInteractive to inspect
the plan without changing your machine, or -KeepDefaults to retain your current
WSL and Terminal defaults.

The standalone install-fonts-user.ps1 and set-terminal-font.ps1 utilities remain
available for manual font-only changes. They are not required by the bootstrap.
The Terminal utility can change fonts across existing profiles; use its
-DefaultsOnly switch to retain explicit per-profile overrides.
