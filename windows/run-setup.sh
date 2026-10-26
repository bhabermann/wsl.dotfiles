#!/usr/bin/env bash
# Windows already owns this distro's root access. Grant sudo only for this
# provisioning process, then restore normal passworded sudo on every exit.
set -euo pipefail
user="$1"; shift
[[ "$EUID" == 0 && "$user" =~ ^[a-z_][a-z0-9_-]{0,30}$ && "$user" != root ]] || exit 2
home="$(getent passwd "$user" | cut -d: -f6)"
[[ -n "$home" && -f "$home/.dotfiles/setup" ]] || exit 2
rule="/etc/sudoers.d/dotfiles-bootstrap-$user"
cleanup() { rm -f "$rule"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
umask 077
printf '%s ALL=(root) NOPASSWD: ALL\n' "$user" > "$rule"
chmod 440 "$rule"
visudo -cf "$rule" >/dev/null
umask 022
cd "$home"
runuser -u "$user" -- env HOME="$home" USER="$user" bash "$home/.dotfiles/setup" "$@"
