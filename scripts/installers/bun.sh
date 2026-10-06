#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/../download.sh"

# Installation reference: https://bun.com/docs/installation
BUN_INSTALL=${BUN_INSTALL:-"$HOME/.bun"}
export BUN_INSTALL
if [ -x "$BUN_INSTALL/bin/bun" ]; then
  printf 'Bun is already installed; skipping.\n'
  exit 0
fi

installer=$(mktemp)
trap 'rm -f "$installer"' 0
download_file https://bun.com/install "$installer"
# The dotfiles already configure PATH; keep Bun's installer from editing .zshrc.
SHELL=/bin/sh bash "$installer" >/dev/null
printf 'Bun installed in %s/bin.\n' "$BUN_INSTALL"
