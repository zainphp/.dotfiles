#!/usr/bin/env zsh
set -euo pipefail

repo_dir=${0:A:h:h}
tmp_root=$(mktemp -d)
tmp_home="$tmp_root/home"
mock_bin="$tmp_root/bin"
fresh_socket="$tmp_root/fresh-agent.sock"
ssh_add_log="$tmp_root/ssh-add.log"

trap 'rm -rf -- "$tmp_root"' EXIT

mkdir -p "$tmp_home/.ssh" "$mock_bin"
printf 'private key placeholder\n' > "$tmp_home/.ssh/testkey"

stale_socket=$(find "/run/user/$(id -u)" /tmp -type s -print -quit 2>/dev/null || true)

cat > "$mock_bin/find" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$mock_bin/ssh-add" <<'EOF'
#!/bin/sh
if [ "${1:-}" = '-l' ]; then
  if [ "$SSH_AUTH_SOCK" = "$FRESH_SOCKET" ]; then
    exit 1
  fi
  exit 2
fi
printf '%s|%s\n' "$SSH_AUTH_SOCK" "$*" >> "$SSH_ADD_LOG"
EOF
cat > "$mock_bin/ssh-agent" <<'EOF'
#!/bin/sh
printf 'SSH_AUTH_SOCK="%s"; export SSH_AUTH_SOCK;\n' "$FRESH_SOCKET"
printf 'SSH_AGENT_PID=4242; export SSH_AGENT_PID;\n'
EOF
cat > "$mock_bin/ssh-keygen" <<'EOF'
#!/bin/sh
printf '256 SHA256:test user@example (ED25519)\n'
EOF
chmod +x "$mock_bin/find" "$mock_bin/ssh-add" "$mock_bin/ssh-agent" "$mock_bin/ssh-keygen"

run_sshauth() {
  local socket="$1"
  local output
  output=$(env \
    HOME="$tmp_home" \
    USER="${USER:-$(id -un)}" \
    PATH="$mock_bin:$PATH" \
    SSH_AUTH_SOCK="$socket" \
    FRESH_SOCKET="$fresh_socket" \
    SSH_ADD_LOG="$ssh_add_log" \
    SSHAUTH_FILE="$repo_dir/zsh/sshauth.zsh" \
    zsh -f -c 'source "$SSHAUTH_FILE"; sshauth testkey' 2>&1) || {
      print -u2 -- "$output"
      return 1
    }
  if [[ "$output" == *'no matches found'* ]]; then
    print -u2 -- "$output"
    return 1
  fi
}

: > "$ssh_add_log"
if [[ -n "$stale_socket" ]]; then
  run_sshauth "$stale_socket"
  [[ "$(cat "$ssh_add_log")" == "$fresh_socket|$tmp_home/.ssh/testkey" ]]
fi

: > "$ssh_add_log"
run_sshauth ''
[[ "$(cat "$ssh_add_log")" == "$fresh_socket|$tmp_home/.ssh/testkey" ]]

printf 'sshauth checks passed\n'
