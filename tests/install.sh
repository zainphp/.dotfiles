#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_home=$(mktemp -d)
trap 'rm -rf "$tmp_home"' 0
trap 'exit 1' HUP INT TERM

printf 'old zsh config\n' > "$tmp_home/.zshrc"
printf 'old git config\n' > "$tmp_home/.gitconfig"
HOME="$tmp_home" "$repo_dir/scripts/install.sh"

[ "$(readlink "$tmp_home/.zshrc")" = "$repo_dir/.zshrc" ]
[ "$(readlink "$tmp_home/.gitconfig")" = "$repo_dir/.gitconfig" ]
set -- "$tmp_home"/.dotfiles-backup.*
[ -d "$1" ]
[ "$(cat "$1/.zshrc")" = 'old zsh config' ]
[ "$(cat "$1/.gitconfig")" = 'old git config' ]

HOME="$tmp_home" "$repo_dir/scripts/install.sh"
set -- "$tmp_home"/.dotfiles-backup.*
[ "$#" -eq 1 ]

mkdir -p "$tmp_home/mock-bin"
cat > "$tmp_home/mock-bin/pacman" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$PACKAGE_TEST_LOG"
EOF
cat > "$tmp_home/mock-bin/sudo" <<'EOF'
#!/bin/sh
exec "$@"
EOF
cat > "$tmp_home/mock-bin/safe-chain" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$tmp_home/mock-bin/pacman" "$tmp_home/mock-bin/sudo" "$tmp_home/mock-bin/safe-chain"
PATH="$tmp_home/mock-bin:$PATH" HOME="$tmp_home" PACKAGE_TEST_LOG="$tmp_home/pacman.log" \
  "$repo_dir/scripts/install.sh" --packages
case "$(cat "$tmp_home/pacman.log")" in
  '-S --needed '*) ;;
  *) exit 1 ;;
esac

printf 'installer checks passed\n'
