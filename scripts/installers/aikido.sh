#!/bin/sh
set -eu

if [ -x "$HOME/.safe-chain/bin/safe-chain" ] || command -v safe-chain >/dev/null 2>&1; then
  printf 'Aikido Safe Chain is already installed; skipping.\n'
  exit 0
fi

# Keep the pinned release and digest in sync with Aikido's install reference.
installer=$(mktemp)
trap 'rm -f "$installer"' 0
curl -fsSL 'https://github.com/AikidoSec/safe-chain/releases/download/1.5.24/install-safe-chain.sh' -o "$installer"
printf '%s  %s\n' '99eb124a3404b3ac99e8b65406b87c4ee049c1d6c17757a7d04991ae60d16e69' "$installer" | sha256sum -c -
sh "$installer" --ci
