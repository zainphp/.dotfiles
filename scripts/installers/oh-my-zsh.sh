#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/../download.sh"

# Installation reference: https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh
ZSH=${ZSH:-"$HOME/.oh-my-zsh"}
export ZSH

if [ -s "$ZSH/oh-my-zsh.sh" ]; then
  printf 'Oh My Zsh is already installed; skipping.\n'
  exit 0
fi
if [ -e "$ZSH" ] || [ -L "$ZSH" ]; then
  printf 'Oh My Zsh directory exists but is incomplete: %s\n' "$ZSH" >&2
  exit 1
fi

installer=$(mktemp)
trap 'rm -f "$installer"' 0
download_file https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh "$installer"
KEEP_ZSHRC=yes RUNZSH=no CHSH=no sh "$installer"

if [ ! -s "$ZSH/oh-my-zsh.sh" ]; then
  printf 'Oh My Zsh installation did not create %s/oh-my-zsh.sh.\n' "$ZSH" >&2
  exit 1
fi
printf 'Oh My Zsh installed in %s.\n' "$ZSH"
