#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/../download.sh"

# Installation reference: https://github.com/Thavarshan/phpvm
PHPVM_DIR=${PHPVM_DIR:-"$HOME/.phpvm"}
export PHPVM_DIR

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
