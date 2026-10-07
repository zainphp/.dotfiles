#!/usr/bin/env bash
set -euo pipefail

if ! command -v pgrep >/dev/null 2>&1 || ! command -v pkill >/dev/null 2>&1; then
  printf 'Cannot request Codex shutdown (pgrep/pkill unavailable); continuing.\n' >&2
  exit 0
fi
if ! pgrep -x codex >/dev/null 2>&1; then
  printf 'No Codex process is running.\n' >&2
  exit 0
fi

pkill -TERM -x codex 2>/dev/null || :
for attempt in {1..30}; do
  if ! pgrep -x codex >/dev/null 2>&1; then
    printf 'Codex closed gracefully.\n' >&2
    exit 0
  fi
  sleep .1
done
printf 'Codex is still running; continuing with a best-effort backup.\n' >&2
