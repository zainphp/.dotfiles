project-path() {
  local bin
  for bin in "$PWD/vendor/bin" "$PWD/node_modules/.bin"; do
    [[ -d "$bin" ]] && path=("$bin" $path)
  done
  return 0
}
