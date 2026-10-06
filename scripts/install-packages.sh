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
    as_root pacman -S --needed --noconfirm "$@"
  elif command -v apt-get >/dev/null 2>&1; then
    as_root apt-get update
    as_root apt-get install --yes "$@"
  else
    printf 'Unsupported package manager; use Arch or Debian/Ubuntu.\n' >&2
    return 1
  fi
}

if command -v pacman >/dev/null 2>&1; then
  install_packages "$repo_dir/packages/arch.txt"
elif command -v apt-get >/dev/null 2>&1; then
  install_packages "$repo_dir/packages/debian.txt"
else
  printf 'Unsupported package manager; use Arch or Debian/Ubuntu.\n' >&2
  exit 1
fi

"$script_dir/installers/aikido.sh"
"$script_dir/installers/bun.sh"
"$script_dir/installers/oh-my-zsh.sh"
"$script_dir/installers/phpvm.sh"
"$script_dir/installers/composer.sh"
