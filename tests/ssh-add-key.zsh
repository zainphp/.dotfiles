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
printf 'another private key\n' > "$tmp_home/.ssh/otherkey"
printf 'public key\n' > "$tmp_home/.ssh/testkey.pub"
printf 'host config\n' > "$tmp_home/.ssh/config"
printf 'known host\n' > "$tmp_home/.ssh/known_hosts"
printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIlegacy authorized key\n' > "$tmp_home/.ssh/authorized_keys2"

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
selection_output=$(printf '2\n' | env \
  HOME="$tmp_home" \
  USER="${USER:-$(id -un)}" \
  PATH="$mock_bin:$PATH" \
  FRESH_SOCKET="$fresh_socket" \
  SSH_ADD_LOG="$ssh_add_log" \
  SSH_ADD_KEY_FILE="$repo_dir/zsh/helpers/ssh-add-key.zsh" \
  zsh -f -c 'source "$SSH_ADD_KEY_FILE"; ssh-add-key' 2>&1) || {
    print -u2 -- "$selection_output"
    exit 1
  }
[[ "$selection_output" == *'Available SSH keys:'*'otherkey'*'testkey'* ]] || {
  print -u2 -- 'SSH key picker did not list the private keys'
  exit 1
}
[[ "$selection_output" != *'testkey.pub'* && "$selection_output" != *'known_hosts'* && "$selection_output" != *'config'* && "$selection_output" != *'authorized_keys2'* ]] || {
  print -u2 -- 'SSH key picker listed SSH metadata or a public key'
  exit 1
}
[[ "$(cat "$ssh_add_log")" == "$fresh_socket|$tmp_home/.ssh/testkey" ]]

: > "$ssh_add_log"
if run_ssh_add_key '' 1 >/dev/null 2>&1; then
  print -u2 'accepted a key without a readable fingerprint'
  exit 1
fi
[[ ! -s "$ssh_add_log" ]]

if ! env HOME="$tmp_home" SSH_ADD_KEY_FILE="$repo_dir/zsh/helpers/ssh-add-key.zsh" \
  ALIASES_FILE="$repo_dir/zsh/aliases.zsh" \
  zsh -f -i -c '
    typeset -gA _comps
    compdef() {
      local completion=$1 name
      shift
      for name in "$@"; do _comps[$name]=$completion; done
    }
    source "$ALIASES_FILE"
    source "$SSH_ADD_KEY_FILE"
    [[ ${_comps[ssh-add-key]} == _ssh-add-key && ${_comps[sshak]} == _ssh-add-key ]]
  ' \
  </dev/null >/dev/null 2>&1; then
  print -u2 'ssh-add-key or sshak completion was not registered'
  exit 1
fi

printf 'SSH key helper checks passed\n'
