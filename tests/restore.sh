#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT

source_home="$tmp_root/source"
restore_home="$tmp_root/home"
backup_dir="$tmp_root/backups"
archive="$backup_dir/important-files-2026-10-06_12-34-56-test.tar.gz"
older_archive="$backup_dir/important-files-2099-01-01_00-00-00-old.tar.gz"
mkdir -p "$source_home/.ssh" "$source_home/projects/demo" \
  "$source_home/.codex/memories" "$source_home/dotfiles" \
  "$restore_home/projects/demo" "$backup_dir"
printf 'private key\n' > "$source_home/.ssh/id_test"
printf 'project data\n' > "$source_home/projects/demo/data"
printf 'memory\n' > "$source_home/.codex/memories/MEMORY.md"
printf 'local config\n' > "$source_home/dotfiles/.zshrc.local"
printf 'shell history\n' > "$source_home/.zsh_history"
printf 'existing project data\n' > "$restore_home/projects/demo/data"
printf 'older project data\n' > "$source_home/projects/demo/data"
tar -czf "$older_archive" -C "$source_home" .ssh projects .codex dotfiles .zsh_history
touch -t 200001010000 "$older_archive"
printf 'project data\n' > "$source_home/projects/demo/data"
tar -czf "$archive" -C "$source_home" .ssh projects .codex dotfiles .zsh_history

if HOME="$restore_home" DOTFILES_BACKUP_DIR="$backup_dir" \
  "$repo_dir/scripts/restore.sh" >/dev/null 2>&1; then
  printf 'restore proceeded without confirmation\n' >&2
  exit 1
fi
[[ $(<"$restore_home/projects/demo/data") == 'existing project data' ]]

HOME="$restore_home" DOTFILES_BACKUP_DIR="$backup_dir" \
  "$repo_dir/scripts/restore.sh" --yes >/dev/null
[[ $(<"$restore_home/.ssh/id_test") == 'private key' ]]
[[ $(<"$restore_home/projects/demo/data") == 'project data' ]]
[[ $(<"$restore_home/.codex/memories/MEMORY.md") == 'memory' ]]
[[ $(<"$restore_home/dotfiles/.zshrc.local") == 'local config' ]]
[[ $(<"$restore_home/.zsh_history") == 'shell history' ]]

default_repo="$tmp_root/default-dotfiles"
default_home="$tmp_root/default-home"
mkdir -p "$default_repo/scripts" "$default_repo/backups" "$default_home"
cp "$repo_dir/scripts/restore.sh" "$default_repo/scripts/restore.sh"
cp "$archive" "$default_repo/backups/"
env -u DOTFILES_BACKUP_DIR HOME="$default_home" \
  "$default_repo/scripts/restore.sh" --yes >/dev/null
[[ $(<"$default_home/projects/demo/data") == 'project data' ]]

# Simulate sudo without touching real users or their home directories.
mock_bin="$tmp_root/bin"
sudo_home="$tmp_root/sudo-home"
root_home="$tmp_root/root-home"
mkdir -p "$mock_bin" "$sudo_home" "$root_home"
cat > "$mock_bin/id" <<'EOF'
#!/bin/sh
printf '%s\n' "${MOCK_UID:-1000}"
EOF
cat > "$mock_bin/getent" <<'EOF'
#!/bin/sh
[ "$1" = passwd ] && [ "$2" = testuser ] || exit 1
printf 'testuser:x:1000:1000::%s:/bin/bash\n' "$TEST_USER_HOME"
EOF
cat > "$mock_bin/sudo" <<'EOF'
#!/bin/sh
[ "$1" = -u ] && [ "$2" = testuser ] && [ "$3" = -- ] || exit 1
shift 3
unset MOCK_UID SUDO_USER
exec "$@"
EOF
chmod +x "$mock_bin"/*
PATH="$mock_bin:$PATH" MOCK_UID=0 SUDO_USER=testuser \
  TEST_USER_HOME="$sudo_home" HOME="$root_home" \
  "$repo_dir/scripts/restore.sh" "$archive" --yes > "$tmp_root/output"
[[ $(<"$sudo_home/projects/demo/data") == 'project data' ]]
[[ ! -e "$root_home/projects" ]]
grep -q 'Checking archive' "$tmp_root/output"
grep -q 'Restoring files' "$tmp_root/output"
grep -Fq "Restore completed: $sudo_home" "$tmp_root/output"
[[ $(<"$tmp_root/output") != *$'\033'* ]]

printf 'restore checks passed\n'
