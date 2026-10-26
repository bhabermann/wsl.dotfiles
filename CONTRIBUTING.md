# Contributing

Keep identities, secrets, machine paths, and generated installation state out of Git.
Prefer Debian packages for Linux CLIs, upstream APT repositories for Docker/mise,
and per-user Windows installers or checksum-verified portable releases.

Run the checks appropriate to your changes:

```bash
bash scripts/test-linux.sh
bash scripts/test-docker.sh
```

```powershell
.\scripts\test-windows.ps1 -FontTest
.\scripts\test-wsl.ps1
```

Do not run normal Windows setup against a contributor's daily-use environment
as a test. Keep test distros uniquely named and verify their registration/disk
paths before cleanup. Preserve UTF-8 text, LF in Linux scripts, and executable
Git modes for Linux entrypoints. Asset updates must include checksums.
