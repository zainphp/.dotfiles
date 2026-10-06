export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export PHPVM_DIR="${PHPVM_DIR:-$HOME/.phpvm}"
typeset -U path PATH
path=(
  "$HOME/.safe-chain/shims"
  "$HOME/.safe-chain/bin"
  "$HOME/.local/bin"
  "$BUN_INSTALL/bin"
  "$PHPVM_DIR/bin"
  "$HOME/.config/composer/vendor/bin"
  $path
)
