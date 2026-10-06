#!/bin/sh
set -eu

# Installation reference: https://getcomposer.org/doc/faqs/how-to-install-composer-programmatically.md
composer_bin="$HOME/.local/bin/composer"
if [ -x "$composer_bin" ]; then
  printf 'Composer is already installed; skipping.\n'
  exit 0
fi
if ! command -v php >/dev/null 2>&1; then
  printf 'Composer requires an active PHP CLI; select a PHP version with PHPVM and rerun the package installer.\n' >&2
  exit 1
fi

installer=$(mktemp)
trap 'rm -f "$installer"' 0
expected_signature=$(curl -fsSL https://composer.github.io/installer.sig)
curl -fsSL https://getcomposer.org/installer -o "$installer"
actual_signature=$(php -r 'echo hash_file("sha384", $argv[1]);' "$installer")
if [ "$expected_signature" != "$actual_signature" ]; then
  printf 'Composer installer signature verification failed.\n' >&2
  exit 1
fi

mkdir -p "$HOME/.local/bin"
php "$installer" --quiet --install-dir="$HOME/.local/bin" --filename=composer
