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

stale_socket="$tmp_root/stale-agent.sock"
: > "$stale_socket"

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
if [ "${SSH_KEYGEN_FAIL:-0}" = 1 ]; then
  exit 1
fi
printf '256 SHA256:test user@example (ED25519)\n'
EOF
chmod +x "$mock_bin/find" "$mock_bin/ssh-add" "$mock_bin/ssh-agent" "$mock_bin/ssh-keygen"

run_ssh_add_key() {
  local socket="$1"
  local keygen_fails="${2:-0}"
  local output
  output=$(env \
    HOME="$tmp_home" \
    USER="${USER:-$(id -un)}" \
    PATH="$mock_bin:$PATH" \
    SSH_AUTH_SOCK="$socket" \
    FRESH_SOCKET="$fresh_socket" \
    SSH_ADD_LOG="$ssh_add_log" \
    SSH_KEYGEN_FAIL="$keygen_fails" \
    SSH_ADD_KEY_FILE="$repo_dir/zsh/helpers/ssh-add-key.zsh" \
    zsh -f -c 'source "$SSH_ADD_KEY_FILE"; ssh-add-key testkey' 2>&1) || {
      print -u2 -- "$output"
      return 1
    }
  if [[ "$output" == *'no matches found'* ]]; then
    print -u2 -- "$output"
    return 1
  fi
}

: > "$ssh_add_log"
run_ssh_add_key "$stale_socket"
[[ "$(cat "$ssh_add_log")" == "$fresh_socket|$tmp_home/.ssh/testkey" ]]

: > "$ssh_add_log"
run_ssh_add_key ''
[[ "$(cat "$ssh_add_log")" == "$fresh_socket|$tmp_home/.ssh/testkey" ]]

: > "$ssh_add_log"
if run_ssh_add_key '' 1 >/dev/null 2>&1; then
  print -u2 'accepted a key without a readable fingerprint'
  exit 1
fi
[[ ! -s "$ssh_add_log" ]]

if ! env HOME="$tmp_home" SSH_ADD_KEY_FILE="$repo_dir/zsh/helpers/ssh-add-key.zsh" \
  ALIASES_FILE="$repo_dir/zsh/aliases.zsh" \
  zsh -f -i -c 'source "$ALIASES_FILE"; source "$SSH_ADD_KEY_FILE"; [[ ${_comps[ssh-add-key]} == _ssh-add-key && ${_comps[sshak]} == _ssh-add-key ]]' \
  </dev/null >/dev/null 2>&1; then
  print -u2 'ssh-add-key or sshak completion was not registered'
  exit 1
fi

printf 'SSH key helper checks passed\n'
