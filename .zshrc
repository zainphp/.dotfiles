# Oh My Zsh
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
ZSH_THEME="robbyrussell"
plugins=(git gh bun)
if [[ -s "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" && -s "$ZSH/oh-my-zsh.sh" ]]; then
  plugins+=(zsh-autosuggestions)
fi

[[ -s "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# Load the distro package unless Oh My Zsh already loaded its custom plugin.
if [[ ! -s "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" || ! -s "$ZSH/oh-my-zsh.sh" ]]; then
  if [[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  elif [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  elif [[ -r "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" ]]; then
    source "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"
  fi
fi

# Preferred editor
if command -v code >/dev/null 2>&1; then
  export EDITOR='code --wait'
else
  export EDITOR=nano
fi
export VISUAL="$EDITOR"

# Runtime paths and initialization
# Resolve this file's directory even when ~/.zshrc is a symlink.
dotfiles_dir="${${(%):-%x}:A:h}"
[[ -r "$dotfiles_dir/zsh/paths.zsh" ]] && source "$dotfiles_dir/zsh/paths.zsh"
[[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"
[[ -s "$PHPVM_DIR/phpvm.sh" ]] && source "$PHPVM_DIR/phpvm.sh"

# Personal commands
[[ -r "$dotfiles_dir/zsh/aliases.zsh" ]] && source "$dotfiles_dir/zsh/aliases.zsh"
[[ -r "$dotfiles_dir/zsh/helpers/ssh-add-key.zsh" ]] && source "$dotfiles_dir/zsh/helpers/ssh-add-key.zsh"

# Machine-specific settings (kept out of Git)
dotfiles_local_config="$dotfiles_dir/.zshrc.local"
[[ -r "$dotfiles_local_config" ]] && source "$dotfiles_local_config"
unset dotfiles_dir dotfiles_local_config
