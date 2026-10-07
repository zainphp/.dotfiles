#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT
tmp_home="$tmp_root/home"
mock_bin="$tmp_root/bin"
backup_script="$tmp_home/.dotfiles/scripts/backup.sh"
mkdir -p "$tmp_home/.dotfiles/scripts" "$tmp_home/.dotfiles/node_modules/pkg" \
  "$tmp_home/.ssh" "$tmp_home/.gnupg" "$tmp_home/projects/demo/node_modules/pkg" \
  "$tmp_home/projects/demo/vendor/pkg" "$tmp_home/projects/demo/.next/cache" \
  "$tmp_home/projects/demo/build" "$tmp_home/projects/demo/dist" \
  "$tmp_home/projects/demo/database" "$tmp_home/projects/demo/storage/uploads" \
  "$tmp_home/.ssh-bak" "$tmp_home/.codex/packages" "$tmp_home/.codex/plugins" \
  "$tmp_home/.codex/.tmp" "$mock_bin"
cp "$repo_dir/scripts/backup.sh" "$backup_script"
cp "$repo_dir/scripts/close-codex.sh" "$tmp_home/.dotfiles/scripts/close-codex.sh"
chmod +x "$backup_script" "$tmp_home/.dotfiles/scripts/close-codex.sh"
printf 'test key\n' > "$tmp_home/.ssh/id_test"
printf 'older test key\n' > "$tmp_home/.ssh-bak/id_old"
printf 'local shell config\n' > "$tmp_home/.dotfiles/.zshrc.local"
printf 'tracked setup file\n' > "$tmp_home/.dotfiles/README.md"
printf 'gpg configuration\n' > "$tmp_home/.gnupg/gpg.conf"
printf 'reinstallable package\n' > "$tmp_home/projects/demo/node_modules/pkg/package.json"
printf 'reinstallable package\n' > "$tmp_home/projects/demo/vendor/pkg/autoload.php"
printf 'reinstallable build output\n' > "$tmp_home/projects/demo/.next/cache/build"
printf 'reinstallable build output\n' > "$tmp_home/projects/demo/build/output.js"
printf 'reinstallable distribution output\n' > "$tmp_home/projects/demo/dist/output.js"
printf 'reinstallable package\n' > "$tmp_home/.dotfiles/node_modules/pkg/package.json"
printf 'before\n' > "$tmp_home/projects/data"
printf 'codex data\n' > "$tmp_home/.codex/session.jsonl"
printf 'auth token\n' > "$tmp_home/.codex/auth.json"
printf 'installed package\n' > "$tmp_home/.codex/packages/package.json"
printf 'installed plugin\n' > "$tmp_home/.codex/plugins/plugin.json"
printf 'temporary data\n' > "$tmp_home/.codex/.tmp/data"

project="$tmp_home/projects/demo"
git -C "$project" init -q
git -C "$project" config user.name 'Backup Test'
git -C "$project" config user.email 'backup-test@example.invalid'
git -C "$project" config commit.gpgsign false
printf '.env\ndatabase/\nstorage/\n' > "$project/.gitignore"
printf 'tracked baseline\n' > "$project/tracked.txt"
printf 'stash baseline\n' > "$project/stash.txt"
git -C "$project" add .gitignore tracked.txt stash.txt
git -C "$project" commit -qm 'backup fixture'
printf 'secret environment value\n' > "$project/.env"
printf 'local database\n' > "$project/database/local.sqlite"
printf 'local upload\n' > "$project/storage/uploads/photo.bin"
printf 'stashed change\n' >> "$project/stash.txt"
git -C "$project" stash push -qm 'backup fixture stash'
printf 'uncommitted tracked change\n' >> "$project/tracked.txt"
printf 'untracked local file\n' > "$project/untracked.txt"

cat > "$mock_bin/date" <<'EOF'
#!/bin/sh
printf '2026-10-06_12-34-56\n'
EOF
cat > "$mock_bin/pgrep" <<'EOF'
#!/bin/sh
[ -e "$MOCK_CODEX_STOPPED" ] && exit 1
printf '123\n'
EOF
cat > "$mock_bin/pkill" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$MOCK_SIGNAL_LOG"
: > "$MOCK_CODEX_STOPPED"
EOF
chmod +x "$mock_bin/date" "$mock_bin/pgrep" "$mock_bin/pkill"

run_backup() {
  printf '%s\n' "${BACKUP_ANSWER:-y}" | PATH="$mock_bin:$PATH" HOME="$tmp_home" \
    MOCK_CODEX_STOPPED="$tmp_home/codex-stopped" \
    MOCK_SIGNAL_LOG="$tmp_home/signals" "$backup_script" "$@"
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
if output=$(BACKUP_ANSWER=n run_backup "$backup_dir" 2>&1); then
  printf 'backup continued without confirmation\n' >&2
  exit 1
fi
case "$output" in
  *'Close other apps that may be changing files'*'Estimated source size:'*'Continue with backup? [y/N]'*'Backup cancelled.'*) ;;
  *) printf 'backup did not warn and ask for confirmation\n' >&2; exit 1 ;;
esac
if compgen -G "$backup_dir/*.tar.gz" >/dev/null; then
  printf 'backup created an archive after cancellation\n' >&2
  exit 1
fi
[[ ! -e "$tmp_home/signals" ]]
dd if=/dev/urandom of="$tmp_home/projects/progress.bin" bs=1M count=11 status=none
truncate -s 512M "$project/build/large-generated-output.bin"
output=$(run_backup "$backup_dir" 2>"$tmp_home/backup-output")
[[ $output == "Backup created: $backup_dir/"* ]]
[[ $(<"$tmp_home/signals") == '-TERM -x codex' ]]
grep -F 'Estimated source size:' "$tmp_home/backup-output" >/dev/null
grep -F 'Close other apps that may be changing files' "$tmp_home/backup-output" >/dev/null
grep -F 'Continue with backup? [y/N]' "$tmp_home/backup-output" >/dev/null
grep -E 'Creating archive .*: \. .*done' "$tmp_home/backup-output" >/dev/null
if grep -Eq 'Estimated source size: ([1-9][0-9]{2,}M|[1-9][0-9]*G|[1-9][0-9]*T)' "$tmp_home/backup-output"; then
  printf 'size estimate included a large generated build file\n' >&2
  exit 1
fi
archive=${output#'Backup created: '}
rm "$tmp_home/projects/progress.bin"
if tar -tzf "$archive" | grep -Eq '^\.codex/(auth\.json|packages(/|$)|plugins(/|$)|\.tmp(/|$))'; then
  printf 'backup archive included excluded Codex files\n' >&2
  exit 1
fi
tar -tzf "$archive" | grep -Fx '.codex/session.jsonl' >/dev/null
tar -tzf "$archive" | grep -Fx '.dotfiles/.zshrc.local' >/dev/null
if tar -tzf "$archive" | grep -Eq '^\.dotfiles/(README\.md|scripts/backup\.sh|node_modules/)'; then
  printf 'backup archive included more than the local dotfiles config\n' >&2
  exit 1
fi
tar -tzf "$archive" | grep -Fx '.gnupg/gpg.conf' >/dev/null
if tar -tzf "$archive" | grep -Fx '.ssh-bak/id_old' >/dev/null; then
  printf 'backup archive included .ssh-bak\n' >&2
  exit 1
fi
if tar -tzf "$archive" | grep -Eq '(^|/)node_modules(/|$)'; then
  printf 'backup archive included node_modules\n' >&2
  exit 1
fi
if tar -tzf "$archive" | grep -Eq '(^|/)(vendor|\.next)(/|$)'; then
  printf 'backup archive included vendor or .next\n' >&2
  exit 1
fi
if tar -tzf "$archive" | grep -Eq '(^|/)(build|dist)(/|$)'; then
  printf 'backup archive included generated build output\n' >&2
  exit 1
fi
for path in \
  projects/demo/.env \
  projects/demo/database/local.sqlite \
  projects/demo/storage/uploads/photo.bin; do
  tar -tzf "$archive" | grep -Fx "$path" >/dev/null || {
    printf 'backup archive omitted ignored local data: %s\n' "$path" >&2
    exit 1
  }
done
restored_home="$tmp_root/restored"
mkdir -p "$restored_home"
tar -xzf "$archive" -C "$restored_home"
restored_project="$restored_home/projects/demo"
[[ $(<"$restored_project/.env") == 'secret environment value' ]]
[[ $(<"$restored_project/tracked.txt") == $'tracked baseline\nuncommitted tracked change' ]]
[[ $(<"$restored_project/untracked.txt") == 'untracked local file' ]]
git -C "$restored_project" stash list --format='%gs' | grep -F 'backup fixture stash' >/dev/null
git -C "$restored_project" stash show -p stash@{0} | grep -F 'stashed change' >/dev/null
git -C "$restored_project" status --porcelain | grep -F ' M tracked.txt' >/dev/null
printf 'after\n' > "$tmp_home/projects/data"
run_backup "$backup_dir" >/dev/null 2>&1

shopt -s nullglob
archives=("$backup_dir"/*.tar.gz)
[[ ${#archives[@]} -eq 2 ]]
first=$(tar -xOzf "${archives[0]}" projects/data)
second=$(tar -xOzf "${archives[1]}" projects/data)
[[ "$first:$second" == 'before:after' || "$first:$second" == 'after:before' ]]

default_backup_dir="$tmp_home/.dotfiles/backups"
output=$(run_backup 2>/dev/null)
[[ $output == "Backup created: $default_backup_dir/"* ]]
run_backup >/dev/null 2>&1
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
cp "$repo_dir/scripts/close-codex.sh" "$nested_repo/scripts/close-codex.sh"
chmod +x "$nested_repo/scripts/backup.sh" "$nested_repo/scripts/close-codex.sh"
output=$(printf 'y\n' | PATH="$mock_bin:$PATH" HOME="$tmp_home" \
  MOCK_CODEX_STOPPED="$tmp_home/codex-stopped" MOCK_SIGNAL_LOG="$tmp_home/signals" \
  "$nested_repo/scripts/backup.sh" 2>/dev/null)
[[ $output == "Backup created: $nested_repo/backups/"* ]]
nested_archive=${output#'Backup created: '}
if tar -tzf "$nested_archive" | grep -F 'projects/dotfiles/backups/' >/dev/null; then
  printf 'nested repository backup included its own backups\n' >&2
  exit 1
fi

printf 'backup checks passed\n'
