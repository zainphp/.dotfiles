ssh-add-key() {
  if [[ -z "${1:-}" ]]; then
    print -u2 'Usage: ssh-add-key key-filename'
    return 1
  fi

  local ssh_key="$HOME/.ssh/$1"
  if [[ ! -f "$ssh_key" ]]; then
    print -u2 "Private key not found: $1"
    return 1
  fi

  local agent_ready=0 agent_status socket
  if [[ -n "${SSH_AUTH_SOCK:-}" && -S "$SSH_AUTH_SOCK" ]]; then
    if ssh-add -l >/dev/null 2>&1; then
      agent_ready=1
    else
      agent_status=$?
      (( agent_status == 1 )) && agent_ready=1
    fi
  fi

  if (( ! agent_ready )); then
    while IFS= read -r socket; do
      export SSH_AUTH_SOCK="$socket"
      if ssh-add -l >/dev/null 2>&1; then
        agent_ready=1
      else
        agent_status=$?
        (( agent_status == 1 )) && agent_ready=1
      fi
      (( agent_ready )) && break
    done < <(find /tmp -maxdepth 2 -type s -user "$USER" -name 'agent.*' -path '/tmp/ssh-*/*' -print 2>/dev/null)
  fi

  if (( ! agent_ready )); then
    unset SSH_AUTH_SOCK
    eval "$(ssh-agent -s)" >/dev/null
  fi

  local fingerprint
  fingerprint=$(ssh-keygen -lf "$ssh_key" 2>/dev/null | awk '{print $2}')
  if [[ -z "$fingerprint" ]]; then
    print -u2 "Could not read key fingerprint: $1"
    return 1
  fi
  if ! ssh-add -l 2>/dev/null | grep -Fq "$fingerprint"; then
    ssh-add "$ssh_key"
  fi
}

_ssh-add-key() {
  _files -W "$HOME/.ssh"
}

if [[ -o interactive ]]; then
  if (( ! $+functions[compdef] )); then
    autoload -Uz compinit
    compinit
  fi
  compdef _ssh-add-key ssh-add-key sshak
fi
