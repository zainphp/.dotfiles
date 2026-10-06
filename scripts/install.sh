#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
backup_dir=

backup_and_link() {
  source_file=$1
  target_file=$2

  if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$source_file" ]; then
    return
  fi

  if [ -e "$target_file" ] || [ -L "$target_file" ]; then
    if [ -z "$backup_dir" ]; then
      backup_dir=$(mktemp -d "$HOME/.dotfiles-backup.XXXXXX")
    fi
    mv "$target_file" "$backup_dir/$(basename "$target_file")"
    printf 'Backed up %s to %s\n' "$target_file" "$backup_dir"
  fi

  ln -s "$source_file" "$target_file"
}

case "${1:-}" in
  '')
    backup_and_link "$repo_dir/.zshrc" "$HOME/.zshrc"
    backup_and_link "$repo_dir/.gitconfig" "$HOME/.gitconfig"
    ;;
  --packages)
    exec "$script_dir/install-packages.sh"
    ;;
  -h|--help)
    printf 'Usage: %s [--packages]\n' "$0"
    printf 'Default: link dotfiles and back up replaced files.\n'
    printf '%s\n' '--packages: install system packages and Aikido Safe Chain.'
    ;;
  *)
    printf 'Usage: %s [--packages]\n' "$0" >&2
    exit 2
    ;;
esac
