#!/usr/bin/env zsh
set -euo pipefail

repo_dir=${0:A:h:h}
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT
project_dir="$tmp_root/project"
mkdir -p "$project_dir/node_modules/.bin" "$project_dir/vendor/bin"
: > "$project_dir/node_modules/.bin/project-tool"
: > "$project_dir/vendor/bin/vendor-tool"
chmod +x "$project_dir/node_modules/.bin/project-tool" "$project_dir/vendor/bin/vendor-tool"

source "$repo_dir/zsh/paths.zsh"
cd "$project_dir"
if command -v project-tool >/dev/null 2>&1 || command -v vendor-tool >/dev/null 2>&1; then
  print -u2 'project tools were available before explicit activation'
  exit 1
fi
source "$repo_dir/zsh/helpers/project-path.zsh"
project-path
command -v project-tool >/dev/null
command -v vendor-tool >/dev/null

printf 'Project PATH checks passed\n'
