#!/bin/sh
set -eu

dotfiles_dir="$HOME/.dotfiles"

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

if [ -e "$dotfiles_dir" ] || [ -L "$dotfiles_dir" ]; then
  if [ ! -e "$dotfiles_dir/.git" ]; then
    printf '%s exists but is not a Git checkout; move it and retry.\n' "$dotfiles_dir" >&2
    exit 1
  fi
fi

if ! command -v git >/dev/null 2>&1; then
  if command -v pacman >/dev/null 2>&1; then
    as_root pacman -S --needed --noconfirm git
  elif command -v apt-get >/dev/null 2>&1; then
    as_root apt-get update
    as_root apt-get install --yes git
  else
    printf 'Unsupported package manager; install Git, then rerun this bootstrap.\n' >&2
    exit 1
  fi
fi

if [ -e "$dotfiles_dir/.git" ]; then
  git -C "$dotfiles_dir" pull --ff-only
else
  git clone https://github.com/zainphp/.dotfiles.git "$dotfiles_dir"
fi

cd "$dotfiles_dir"
./scripts/install-packages.sh
./scripts/symlink-dotfiles.sh
printf '\nBootstrap complete. Open a new terminal session to use Zsh. If you have a backup archive, restore it with:\n  %s/scripts/restore.sh /path/to/backup.tar.gz\n' \
  "$dotfiles_dir"
printf 'Check packages and binaries with:\n  %s/scripts/check-packages.sh\n' "$dotfiles_dir"
