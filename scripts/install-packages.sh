#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

install_packages() {
  package_file=$1
  set --
  while IFS= read -r package || [ -n "$package" ]; do
    case "$package" in
      ''|'#'*) continue ;;
    esac
    set -- "$@" "$package"
  done < "$package_file"

  [ "$#" -gt 0 ] || return 0

  if command -v pacman >/dev/null 2>&1; then
    as_root pacman -S --needed "$@"
  elif command -v apt-get >/dev/null 2>&1; then
    as_root apt-get update
    as_root apt-get install --yes "$@"
  else
    printf 'Unsupported package manager; use Arch or Debian/Ubuntu.\n' >&2
    return 1
  fi
}

install_aikido() {
  if [ -x "$HOME/.safe-chain/bin/safe-chain" ] || command -v safe-chain >/dev/null 2>&1; then
    printf 'Aikido Safe Chain is already installed; skipping.\n'
    return
  fi

  # Keep the pinned release and digest in sync with Aikido's install instructions.
  installer=$(mktemp)
  trap 'rm -f "$installer"' 0
  curl -fsSL 'https://github.com/AikidoSec/safe-chain/releases/download/1.5.24/install-safe-chain.sh' -o "$installer"
  printf '%s  %s\n' '99eb124a3404b3ac99e8b65406b87c4ee049c1d6c17757a7d04991ae60d16e69' "$installer" | sha256sum -c -
  sh "$installer" --ci
}

if command -v pacman >/dev/null 2>&1; then
  install_packages "$repo_dir/packages/arch.txt"
elif command -v apt-get >/dev/null 2>&1; then
  install_packages "$repo_dir/packages/debian.txt"
else
  printf 'Unsupported package manager; use Arch or Debian/Ubuntu.\n' >&2
  exit 1
fi

install_aikido
