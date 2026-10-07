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

backup_locations=(
  "$dotfiles_path/.zshrc.local"
  .ssh
  .gnupg
  projects
  .codex
  .zsh_history
)
backup_paths=()
for path in "${backup_locations[@]}"; do
  [[ -e "$home_dir/$path" ]] && backup_paths+=("$path")
done

# Shared by the estimate and archive so both use the same exclusions.
backup_excludes=(
  # Prevent the default archive from being included in future archives.
  "--exclude=$dotfiles_path/backups"

  # Reinstallable project dependencies and generated output.
  '--exclude=node_modules'
  '--exclude=vendor'
  '--exclude=.next'
  '--exclude=build'
  '--exclude=dist'

  # Reinstallable Codex data and credentials that can be recreated by signing in.
  '--exclude=.codex/packages'
  '--exclude=.codex/plugins'
  '--exclude=.codex/.tmp'
  '--exclude=.codex/auth.json'
)
printf 'Close other apps that may be changing files; Codex will be asked to close after confirmation. Live app data may be incomplete.\n' >&2
estimated_size=$(
  cd "$home_dir"
  du -sch --apparent-size "${backup_excludes[@]}" "${backup_paths[@]}" |
    awk 'END { print $1 }'
)
printf 'Estimated source size: %s (before compression).\n' "$estimated_size" >&2
printf 'Continue with backup? [y/N] ' >&2
if ! IFS= read -r answer; then answer=; fi
case "$answer" in
  [yY]|[yY][eE][sS]) ;;
  *) printf 'Backup cancelled.\n' >&2; exit 1 ;;
esac

"$script_dir/close-codex.sh"
archive=$(mktemp --tmpdir="$backup_dir" --suffix=.tar.gz \
  "important-files-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX")
printf 'Creating archive (one dot per ~10 MiB): ' >&2
tar -czf "$archive" --checkpoint=1024 --checkpoint-action=dot \
  "${backup_excludes[@]}" \
  -C "$home_dir" "${backup_paths[@]}" >&2
printf ' done\n' >&2

printf 'Backup created: %s\n' "$archive"
