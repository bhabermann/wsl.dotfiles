# Contributing

This is a personal WSL dotfiles repository, but small fixes and portability
improvements are welcome.

Before opening a pull request:

- Keep machine-specific identity, secrets, hostnames, and corporate details out
  of the repository.
- Prefer Ubuntu apt for WSL system tools and general CLIs.
- Install mise through its APT repository and use it only for global developer
  language runtimes and project version switching.
- Run the smoke tests when touching setup behavior:

```bash
bash -n setup lib/common.sh lib/tools.sh install/*.sh scripts/*.sh scripts/update-corporate-ca
./scripts/test-docker.sh
```

Use concise conventional commit messages when possible.
