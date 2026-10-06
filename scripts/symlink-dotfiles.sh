#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

if [ "$#" -gt 0 ]; then
  printf 'Usage: %s\n' "$0" >&2
  exit 2
fi

ln -sfT "$repo_dir/.zshrc" "$HOME/.zshrc"
ln -sfT "$repo_dir/.gitconfig" "$HOME/.gitconfig"
