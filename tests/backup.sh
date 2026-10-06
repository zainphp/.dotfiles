#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT
tmp_home="$tmp_root/home"
mock_bin="$tmp_root/bin"
backup_script="$tmp_home/.dotfiles/scripts/backup.sh"
mkdir -p "$tmp_home/.dotfiles/scripts" "$tmp_home/.ssh" "$tmp_home/projects" \
  "$tmp_home/.codex/packages" "$tmp_home/.codex/plugins" "$tmp_home/.codex/.tmp" "$mock_bin"
cp "$repo_dir/scripts/backup.sh" "$backup_script"
chmod +x "$backup_script"
printf 'test key\n' > "$tmp_home/.ssh/id_test"
printf 'before\n' > "$tmp_home/projects/data"
printf 'codex data\n' > "$tmp_home/.codex/session.jsonl"
printf 'auth token\n' > "$tmp_home/.codex/auth.json"
printf 'installed package\n' > "$tmp_home/.codex/packages/package.json"
printf 'installed plugin\n' > "$tmp_home/.codex/plugins/plugin.json"
printf 'temporary data\n' > "$tmp_home/.codex/.tmp/data"

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
if run_backup "$tmp_home/.dotfiles" >/dev/null 2>&1; then
  printf 'backup accepted the dotfiles repository as its destination\n' >&2
  exit 1
fi

backup_dir="$tmp_home/backups"
output=$(run_backup "$backup_dir")
[[ $output == "Backup created: $backup_dir/"* ]]
archive=${output#'Backup created: '}
if tar -tzf "$archive" | grep -Eq '^\.codex/(auth\.json|packages(/|$)|plugins(/|$)|\.tmp(/|$))'; then
  printf 'backup archive included excluded Codex files\n' >&2
  exit 1
fi
tar -tzf "$archive" | grep -Fx '.codex/session.jsonl' >/dev/null
printf 'after\n' > "$tmp_home/projects/data"
run_backup "$backup_dir" >/dev/null

shopt -s nullglob
archives=("$backup_dir"/*.tar.gz)
[[ ${#archives[@]} -eq 2 ]]
first=$(tar -xOzf "${archives[0]}" projects/data)
second=$(tar -xOzf "${archives[1]}" projects/data)
[[ "$first:$second" == 'before:after' || "$first:$second" == 'after:before' ]]

default_backup_dir="$tmp_home/.dotfiles/backups"
output=$(run_backup)
[[ $output == "Backup created: $default_backup_dir/"* ]]
run_backup >/dev/null
archives=("$default_backup_dir"/*.tar.gz)
[[ ${#archives[@]} -eq 2 ]]
for archive in "${archives[@]}"; do
  if tar -tzf "$archive" | grep -F '.dotfiles/backups/' >/dev/null; then
    printf 'backup archive included older backups\n' >&2
    exit 1
  fi
done

nested_repo="$tmp_home/projects/dotfiles"
mkdir -p "$nested_repo/scripts"
cp "$repo_dir/scripts/backup.sh" "$nested_repo/scripts/backup.sh"
chmod +x "$nested_repo/scripts/backup.sh"
output=$(PATH="$mock_bin:$PATH" HOME="$tmp_home" "$nested_repo/scripts/backup.sh")
[[ $output == "Backup created: $nested_repo/backups/"* ]]
nested_archive=${output#'Backup created: '}
if tar -tzf "$nested_archive" | grep -F 'projects/dotfiles/backups/' >/dev/null; then
  printf 'nested repository backup included its own backups\n' >&2
  exit 1
fi

printf 'backup checks passed\n'
