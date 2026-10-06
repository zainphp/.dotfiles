#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_dir=$(cd -- "$script_dir/.." && pwd -P)
backup_dir=${DOTFILES_BACKUP_DIR:-$repo_dir/backups}
archive=
assume_yes=0

usage() {
  printf 'Usage: %s [archive.tar.gz] [--yes]\n' "$0"
}

for arg in "$@"; do
  case $arg in
    -h|--help)
      usage
      exit 0
      ;;
    -y|--yes)
      assume_yes=1
      ;;
    -*)
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n $archive ]]; then
        usage >&2
        exit 2
      fi
      archive=$arg
      ;;
  esac
done

if [[ -z $archive ]]; then
  shopt -s nullglob
  archives=("$backup_dir"/important-files-*.tar.gz)
  for candidate in "${archives[@]}"; do
    [[ -f $candidate ]] || continue
    if [[ -z $archive || $candidate -nt $archive ]]; then
      archive=$candidate
    fi
  done
  if [[ -z $archive ]]; then
    printf 'No backup archives found in %s\n' "$backup_dir" >&2
    exit 1
  fi
fi

if [[ ! -f $archive ]]; then
  printf 'Backup archive not found: %s\n' "$archive" >&2
  exit 1
fi
archive_dir=$(cd -- "$(dirname -- "$archive")" && pwd -P)
archive="$archive_dir/$(basename -- "$archive")"
if ! tar -tzf "$archive" >/dev/null; then
  printf 'Could not read backup archive: %s\n' "$archive" >&2
  exit 1
fi

home_dir=$(cd -- "$HOME" && pwd -P)
printf 'Archive: %s\nRestore to: %s\n' "$archive" "$home_dir"
if (( ! assume_yes )); then
  if [[ ! -t 0 ]]; then
    printf 'Refusing to restore without confirmation; pass --yes to proceed.\n' >&2
    exit 1
  fi
  read -r -p 'This may overwrite existing files. Continue? [y/N] ' answer
  case $answer in
    y|Y|yes|YES|Yes) ;;
    *) printf 'Restore cancelled.\n'; exit 1 ;;
  esac
fi

tar --no-same-owner -xzf "$archive" -C "$home_dir"
printf 'Restore completed.\n'
