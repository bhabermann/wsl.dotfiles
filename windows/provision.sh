#!/usr/bin/env bash
# Root-only initial system provisioning; no passwords are accepted as arguments.
set -euo pipefail
user="$1"
[[ "$EUID" == 0 && "$user" =~ ^[a-z_][a-z0-9_-]{0,30}$ && "$user" != root ]] || exit 2
if id "$user" >/dev/null 2>&1 && (( $(id -u "$user") < 1000 )); then
  echo "Choose a normal user name, not an existing system account." >&2
  exit 2
fi
if [[ -e /etc/dotfiles-wsl-owner && "$(< /etc/dotfiles-wsl-owner)" != "$user" ]]; then
  echo "Managed Linux user differs; refusing to adopt another account." >&2
  exit 1
fi
# The slim container rootfs blocks service startup and excludes locales.
rm -f /usr/sbin/policy-rc.d
if [[ -f /etc/dpkg/dpkg.cfg.d/docker ]]; then
  sed -i '\@path-exclude=/usr/share/locale@d' /etc/dpkg/dpkg.cfg.d/docker
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends systemd systemd-sysv dbus dbus-user-session libpam-systemd sudo passwd \
  ca-certificates curl git locales zsh
if ! id "$user" >/dev/null 2>&1; then useradd --create-home --shell /usr/bin/zsh --groups sudo "$user"; fi
usermod -aG sudo "$user"
printf '%s\n' "$user" > /etc/dotfiles-wsl-owner
cat > /etc/wsl.conf <<EOF
[boot]
systemd=true
[user]
default=$user
[interop]
enabled=true
appendWindowsPath=true
[automount]
enabled=true
options=metadata
EOF
apt-get clean
