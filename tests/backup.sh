#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT
tmp_home="$tmp_root/home"
mock_bin="$tmp_root/bin"
backup_script="$tmp_home/.dotfiles/scripts/backup.sh"
mkdir -p "$tmp_home/.dotfiles/scripts" "$tmp_home/.ssh" "$tmp_home/projects" "$tmp_home/.codex" "$mock_bin"
cp "$repo_dir/scripts/backup.sh" "$backup_script"
chmod +x "$backup_script"
printf 'test key\n' > "$tmp_home/.ssh/id_test"
printf 'before\n' > "$tmp_home/projects/data"
printf 'codex data\n' > "$tmp_home/.codex/session.jsonl"

cat > "$mock_bin/date" <<'EOF'
#!/bin/sh
printf '2026-10-06_12-34-56\n'
EOF
cat > "$mock_bin/pgrep" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$mock_bin/date" "$mock_bin/pgrep"

run_backup() {
  PATH="$mock_bin:$PATH" HOME="$tmp_home" "$backup_script" "$@"
}

if run_backup "$tmp_home/projects/backups" >/dev/null 2>&1; then
  printf 'backup accepted a destination inside projects\n' >&2
  exit 1
fi
if run_backup "$tmp_home/.dotfiles/backups" >/dev/null 2>&1; then
  printf 'backup accepted a destination inside the dotfiles tree\n' >&2
  exit 1
fi

backup_dir="$tmp_home/backups"
run_backup "$backup_dir" >/dev/null
printf 'after\n' > "$tmp_home/projects/data"
run_backup "$backup_dir" >/dev/null

shopt -s nullglob
archives=("$backup_dir"/*.tar.gz)
[[ ${#archives[@]} -eq 2 ]]
first=$(tar -xOzf "${archives[0]}" projects/data)
second=$(tar -xOzf "${archives[1]}" projects/data)
[[ "$first:$second" == 'before:after' || "$first:$second" == 'after:before' ]]

printf 'backup checks passed\n'
