#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
  printf 'Usage: %s [backup-directory]\n' "$0"
  exit 0
fi
if (( $# > 1 )); then
  printf 'Usage: %s [backup-directory]\n' "$0" >&2
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_dir=$(cd -- "$script_dir/.." && pwd -P)
home_dir=$(cd -- "$HOME" && pwd -P)
if [[ $repo_dir != "$home_dir/"* ]]; then
  printf 'Keep this dotfiles directory under HOME so it can be archived.\n' >&2
  exit 1
fi
dotfiles_path=${repo_dir#"$home_dir"/}
backup_dir=${1:-${DOTFILES_BACKUP_DIR:-$repo_dir/backups}}

if command -v pgrep >/dev/null 2>&1 &&
  pgrep -a -x codex | grep -vF 'codex app-server' >/dev/null; then
  printf 'Close Codex before backing up its history databases.\n' >&2
  exit 1
fi
# ponytail: relies on Codex's internal lock directory; use a supported API if one appears.
codex_locks="$home_dir/.codex/thread-writer-locks"
if [[ -d $codex_locks ]]; then
  if ! command -v flock >/dev/null 2>&1; then
    printf 'Cannot check Codex history locks without flock; install util-linux before backing up.\n' >&2
    exit 1
  fi
  for lock in "$codex_locks"/*.lock; do
    [[ -e $lock ]] || continue
    if ! flock -n "$lock" true; then
      printf 'Close Codex before backing up its history databases.\n' >&2
      exit 1
    fi
  done
fi

mkdir -p -- "$backup_dir"
backup_dir=$(cd -- "$backup_dir" && pwd -P)
for included_dir in "$home_dir/projects" "$repo_dir"; do
  if [[ -d "$included_dir" ]]; then
    included_dir=$(cd -- "$included_dir" && pwd -P)
    case "$backup_dir/" in
      "$repo_dir/backups/"*) continue ;;
    esac
    case "$backup_dir/" in
      "$included_dir/"*)
        printf 'Choose a backup directory outside %s.\n' "$included_dir" >&2
        exit 1
        ;;
    esac
  fi
done

archive=$(mktemp --tmpdir="$backup_dir" --suffix=.tar.gz \
  "important-files-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX")
backup_paths=("$dotfiles_path")
for path in .ssh projects .codex .zsh_history; do
  [[ -e "$home_dir/$path" ]] && backup_paths+=("$path")
done

tar -czf "$archive" \
  --exclude="$dotfiles_path/backups" \
  --exclude='.codex/packages' \
  --exclude='.codex/plugins' \
  --exclude='.codex/.tmp' \
  --exclude='.codex/auth.json' \
  -C "$home_dir" "${backup_paths[@]}"

printf 'Backup created: %s\n' "$archive"
