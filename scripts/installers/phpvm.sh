#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/../download.sh"

# Installation reference: https://github.com/Thavarshan/phpvm
PHPVM_DIR=${PHPVM_DIR:-"$HOME/.phpvm"}
export PHPVM_DIR

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

if [ ! -x "$PHPVM_DIR/bin/phpvm" ]; then
  installer_dir=$(mktemp -d)
  trap 'rm -rf "$installer_dir"' 0
  download_file https://raw.githubusercontent.com/Thavarshan/phpvm/main/install.sh "$installer_dir/install.sh"
  : > "$installer_dir/profile"
  PROFILE="$installer_dir/profile" bash "$installer_dir/install.sh"

  if [ ! -x "$PHPVM_DIR/bin/phpvm" ]; then
    printf 'PHPVM installation did not create %s/bin/phpvm.\n' "$PHPVM_DIR" >&2
    exit 1
  fi
  printf 'PHPVM installed in %s.\n' "$PHPVM_DIR"
else
  printf 'PHPVM is already installed; skipping manager installation.\n'
fi

"$PHPVM_DIR/bin/phpvm" install latest-remote
"$PHPVM_DIR/bin/phpvm" use latest

if command -v apt-get >/dev/null 2>&1; then
  php_version=$(php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')
  if ! printf '%s\n' "$php_version" | grep -Eq '^[0-9]+\.[0-9]+$'; then
    printf 'Could not determine the active PHP major.minor version: %s\n' "$php_version" >&2
    exit 1
  fi
  as_root apt-get install --yes \
    "php${php_version}-curl" \
    "php${php_version}-mbstring" \
    "php${php_version}-mysql" \
    "php${php_version}-sqlite3" \
    "php${php_version}-xml"
fi

if command -v pacman >/dev/null 2>&1; then
  as_root sed -i \
    -e 's/^;extension=pdo_mysql$/extension=pdo_mysql/' \
    -e 's/^;extension=pdo_sqlite$/extension=pdo_sqlite/' \
    -e 's/^;extension=sqlite3$/extension=sqlite3/' \
    /etc/php/php.ini
fi

php_modules=$(php -m)
for extension in ctype curl dom fileinfo filter hash mbstring openssl pcre PDO session tokenizer xml pdo_mysql pdo_sqlite sqlite3; do
  if ! printf '%s\n' "$php_modules" | grep -Fxiq "$extension"; then
    printf 'Required Laravel PHP extension is not enabled: %s\n' "$extension" >&2
    exit 1
  fi
done
