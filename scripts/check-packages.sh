#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
if command -v pacman >/dev/null 2>&1; then
  package_manager=pacman
  package_file="$repo_dir/packages/arch.txt"
elif command -v apt-get >/dev/null 2>&1 && command -v dpkg-query >/dev/null 2>&1; then
  package_manager=dpkg-query
  package_file="$repo_dir/packages/debian.txt"
else
  printf 'Unsupported package manager; use Arch or Debian/Ubuntu.\n' >&2
  exit 1
fi

missing=0
printf 'System packages (%s):\n' "$package_manager"
while IFS= read -r package || [ -n "$package" ]; do
  case "$package" in
    ''|'#'*) continue ;;
  esac
  if [ "$package_manager" = pacman ]; then
    package_info=$(pacman -Q "$package" 2>/dev/null || true)
    if [ -n "$package_info" ]; then
      version=${package_info#* }
    else
      missing=1
    fi
  else
    package_info=$(dpkg-query -W -f='${db:Status-Status} ${Version}' "$package" 2>/dev/null || true)
    if [ "${package_info%% *}" = installed ]; then
      version=${package_info#* }
    else
      missing=1
    fi
  fi
  if [ -n "${version:-}" ]; then
    printf 'installed: %s %s\n' "$package" "$version"
  else
    printf 'missing: %s\n' "$package"
  fi
  unset version
done < "$package_file"

check_binary() {
  name=$1
  binary=$2
  version_arg=$3
  optional=${4:-no}

  case "$binary" in
    */*)
      if [ -x "$binary" ]; then executable=$binary; else executable=; fi
      ;;
    *) executable=$(command -v "$binary" 2>/dev/null || true) ;;
  esac
  if [ -z "$executable" ]; then
    if [ "$optional" = yes ]; then
      printf 'optional missing: %s\n' "$name"
    else
      printf 'missing: %s\n' "$name"
      missing=1
    fi
  elif [ "$version_arg" = none ]; then
    printf 'installed: %s (%s; version unavailable)\n' "$name" "$executable"
  elif version=$("$executable" "$version_arg" 2>&1); then
    printf 'installed: %s %s\n' "$name" "$version"
  else
    printf 'missing: %s (version check failed)\n' "$name"
    missing=1
  fi
}

printf '\nREADME binaries:\n'
check_binary zsh zsh --version
check_binary code code --version yes
check_binary nano nano --version
check_binary codex codex --version

BUN_INSTALL=${BUN_INSTALL:-"$HOME/.bun"}
PHPVM_DIR=${PHPVM_DIR:-"$HOME/.phpvm"}
check_binary bun "$BUN_INSTALL/bin/bun" --version yes
check_binary phpvm "$PHPVM_DIR/bin/phpvm" --version yes
check_binary php php --version
check_binary composer "$HOME/.local/bin/composer" --version
check_binary laravel "$HOME/.config/composer/vendor/bin/laravel" --version

check_binary git git --version
check_binary gh gh --version
check_binary ssh ssh -V
check_binary rg rg --version
check_binary btop btop --version
check_binary htop htop --version
check_binary sqlite3 sqlite3 --version
if command -v chromium >/dev/null 2>&1; then
  check_binary chromium chromium --version
else
  check_binary chromium chromium-browser --version
fi
check_binary curl curl --version
check_binary unzip unzip -v

if [ -x "$HOME/.safe-chain/bin/safe-chain" ]; then
  safe_chain="$HOME/.safe-chain/bin/safe-chain"
else
  safe_chain=$(command -v safe-chain 2>/dev/null || true)
fi
check_binary safe-chain "${safe_chain:-/nonexistent}" --version
check_binary sentry-mcp "$BUN_INSTALL/bin/sentry-mcp" none

if [ "$missing" -ne 0 ]; then
  exit 1
fi
printf '\nAll required packages and binaries are installed.\n'
