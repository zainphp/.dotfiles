#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
step=0
total_steps=7

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  blue=$(printf '\033[34m')
  green=$(printf '\033[32m')
  red=$(printf '\033[31m')
  reset=$(printf '\033[0m')
else
  blue=
  green=
  red=
  reset=
fi

run_step() {
  label=$1
  shift
  step=$((step + 1))

  printf '%s📦 [%s/%s] %s (0%%)%s\n' "$blue" "$step" "$total_steps" "$label" "$reset"
  if "$@" >/dev/null; then
    printf '%s✅ [%s/%s] %s (100%%)%s\n' "$green" "$step" "$total_steps" "$label" "$reset"
  else
    status=$?
    printf '%s❌ [%s/%s] Failed: %s%s\n' "$red" "$step" "$total_steps" "$label" "$reset" >&2
    return "$status"
  fi
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

set_default_shell() {
  username=$(id -un) || return $?
  zsh_path=$(command -v zsh) || return $?
  passwd_entry=$(getent passwd "$username") || return $?
  current_shell=${passwd_entry##*:}
  [ "$current_shell" = "$zsh_path" ] || as_root chsh -s "$zsh_path" "$username"
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

  if [ "$package_manager" = pacman ]; then
    as_root pacman -S --needed --noconfirm "$@"
  else
    as_root apt-get update && as_root apt-get install --yes "$@"
  fi
}

if command -v pacman >/dev/null 2>&1; then
  package_manager=pacman
  package_file="$repo_dir/packages/arch.txt"
elif command -v apt-get >/dev/null 2>&1; then
  package_manager=apt-get
  package_file="$repo_dir/packages/debian.txt"
else
  printf 'Unsupported package manager; use Arch or Debian/Ubuntu.\n' >&2
  exit 1
fi

run_step "System packages ($package_manager)" install_packages "$package_file"
run_step 'Aikido Safe Chain' "$script_dir/installers/aikido.sh"
run_step Bun "$script_dir/installers/bun.sh"
run_step 'Oh My Zsh' "$script_dir/installers/oh-my-zsh.sh"
run_step 'Set Zsh as default shell' set_default_shell
run_step PHPVM "$script_dir/installers/phpvm.sh"
run_step Composer "$script_dir/installers/composer.sh"
printf '\n🎉 Package setup complete.\n'
