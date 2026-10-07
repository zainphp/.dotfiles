ssh-add-key() {
  local ssh_key key_name candidate
  if [[ -n "${1:-}" ]]; then
    key_name=$1
  else
    local -a keys
    for candidate in "$HOME"/.ssh/*(N); do
      [[ -f "$candidate" && -r "$candidate" ]] || continue
      key_name=${candidate:t}
      case "$key_name" in
        *.pub|config|known_hosts*|authorized_keys|authorized_keys2|environment|rc) continue ;;
      esac
      keys+=("$key_name")
    done

    if (( ! ${#keys} )); then
      print -u2 'No SSH private keys found in ~/.ssh.'
      return 1
    fi

    print 'Available SSH keys:'
    local PS3='Select a key number: '
    select key_name in "${keys[@]}"; do
      [[ -n "$key_name" ]] && break
      print -u2 'Choose a listed key number.'
    done
  fi

  ssh_key="$HOME/.ssh/$key_name"
  if [[ ! -f "$ssh_key" ]]; then
    print -u2 "Private key not found: $key_name"
    return 1
  fi

  local agent_ready=0 agent_status socket
  if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
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
    print -u2 "Could not read key fingerprint: $key_name"
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
