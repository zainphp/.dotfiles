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
if [ "${1:-}" = '-Q' ]; then
  [ "$2" != sqlite ] || exit 1
  printf '%s 1.0\n' "$2"
  exit 0
fi
printf '%s\n' "$*" > "$PACKAGE_TEST_LOG"
EOF
cat > "$tmp_home/mock-bin/sudo" <<'EOF'
#!/bin/sh
exec "$@"
EOF
cat > "$tmp_home/mock-bin/safe-chain" <<'EOF'
#!/bin/sh
printf 'safe-chain 1.5.24\n'
EOF
cat > "$tmp_home/mock-bin/bun" <<'EOF'
#!/bin/sh
exit 0
EOF
mkdir -p "$tmp_home/.bun/bin" "$tmp_home/.local/bin" "$tmp_home/.phpvm/bin" \
  "$tmp_home/.config/composer/vendor/bin"
cat > "$tmp_home/.bun/bin/bun" <<'EOF'
#!/bin/sh
printf '1.2.3\n'
EOF
cat > "$tmp_home/.local/bin/composer" <<'EOF'
#!/bin/sh
printf 'Composer version 2.8.0\n'
EOF
cat > "$tmp_home/.phpvm/bin/phpvm" <<'EOF'
#!/bin/sh
printf 'phpvm 1.0\n'
EOF
cat > "$tmp_home/.config/composer/vendor/bin/laravel" <<'EOF'
#!/bin/sh
printf 'Laravel Installer 1.0\n'
EOF
cat > "$tmp_home/.bun/bin/sentry-mcp" <<'EOF'
#!/bin/sh
exit 0
EOF
for binary in zsh code nano codex php git gh ssh rg btop htop sqlite3 chromium curl unzip; do
  cat > "$tmp_home/mock-bin/$binary" <<EOF
#!/bin/sh
printf '%s 1.0\\n' '$binary'
EOF
  chmod +x "$tmp_home/mock-bin/$binary"
done
chmod +x "$tmp_home/mock-bin/pacman" "$tmp_home/mock-bin/sudo" \
  "$tmp_home/mock-bin/safe-chain" "$tmp_home/mock-bin/bun" \
  "$tmp_home/.bun/bin/bun" "$tmp_home/.local/bin/composer" \
  "$tmp_home/.phpvm/bin/phpvm" "$tmp_home/.config/composer/vendor/bin/laravel" \
  "$tmp_home/.bun/bin/sentry-mcp"
output=$(PATH="$tmp_home/mock-bin:$PATH" HOME="$tmp_home" BUN_INSTALL="$tmp_home/.bun" \
  PACKAGE_TEST_LOG="$tmp_home/pacman.log" "$repo_dir/scripts/install.sh" --packages)
case "$output" in
  *'Aikido Safe Chain is already installed; skipping.'*'Bun is already installed; skipping.'*'Composer is already installed; skipping.'*) ;;
  *) printf 'per-tool installers were not all run\n' >&2; exit 1 ;;
esac
case "$(cat "$tmp_home/pacman.log")" in
  '-S --needed '*) ;;
  *) exit 1 ;;
esac
if output=$(PATH="$tmp_home/mock-bin:$PATH" HOME="$tmp_home" BUN_INSTALL="$tmp_home/.bun" \
  "$repo_dir/scripts/check-packages.sh" 2>&1); then
  printf 'package checker did not report a missing Arch package\n' >&2
  exit 1
fi
case "$output" in
  *'missing: sqlite'*) ;;
  *) printf 'package checker missed the absent Arch package\n' >&2; exit 1 ;;
esac

apt_mock_bin="$tmp_home/apt-mock-bin"
mkdir -p "$apt_mock_bin"
ln -s "$(command -v dirname)" "$apt_mock_bin/dirname"
cat > "$apt_mock_bin/id" <<'EOF'
#!/bin/sh
printf '0\n'
EOF
cat > "$apt_mock_bin/apt-get" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PACKAGE_TEST_LOG"
EOF
cat > "$apt_mock_bin/safe-chain" <<'EOF'
#!/bin/sh
printf 'safe-chain 1.5.24\n'
EOF
cat > "$apt_mock_bin/bun" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$apt_mock_bin/dpkg-query" <<'EOF'
#!/bin/sh
if [ "$3" = "${MISSING_PACKAGE:-sqlite3}" ]; then
  exit 1
fi
printf 'installed 1.0\n'
EOF
chmod +x "$apt_mock_bin/id" "$apt_mock_bin/apt-get" "$apt_mock_bin/safe-chain" \
  "$apt_mock_bin/bun" "$apt_mock_bin/dpkg-query"
for binary in zsh code nano codex php git gh ssh rg btop htop sqlite3 chromium curl unzip; do
  cp "$tmp_home/mock-bin/$binary" "$apt_mock_bin/$binary"
done
: > "$tmp_home/apt.log"
PATH="$apt_mock_bin" HOME="$tmp_home" BUN_INSTALL="$tmp_home/.bun" PACKAGE_TEST_LOG="$tmp_home/apt.log" \
  "$repo_dir/scripts/install.sh" --packages
[ "$(sed -n '1p' "$tmp_home/apt.log")" = update ]
case " $(sed -n '2p' "$tmp_home/apt.log") " in
  *' sqlite3 '*) ;;
  *) printf 'Debian package list was not passed to apt-get\n' >&2; exit 1 ;;
esac
if output=$(PATH="$apt_mock_bin" HOME="$tmp_home" BUN_INSTALL="$tmp_home/.bun" \
  "$repo_dir/scripts/check-packages.sh" 2>&1); then
  printf 'package checker did not report a missing Debian package\n' >&2
  exit 1
fi
case "$output" in
  *'missing: sqlite3'*) ;;
  *) printf 'package checker missed the absent Debian package\n' >&2; exit 1 ;;
esac
mv "$tmp_home/.local/bin/composer" "$tmp_home/composer"
if output=$(PATH="$apt_mock_bin" HOME="$tmp_home" BUN_INSTALL="$tmp_home/.bun" MISSING_PACKAGE=none \
  "$repo_dir/scripts/check-packages.sh" 2>&1); then
  printf 'package checker did not report a missing Composer install\n' >&2
  exit 1
fi
case "$output" in
  *'missing: composer'*) ;;
  *) printf 'package checker missed the absent Composer install\n' >&2; exit 1 ;;
esac
mv "$tmp_home/composer" "$tmp_home/.local/bin/composer"
mv "$apt_mock_bin/codex" "$tmp_home/codex"
if output=$(PATH="$apt_mock_bin" HOME="$tmp_home" BUN_INSTALL="$tmp_home/.bun" MISSING_PACKAGE=none \
  "$repo_dir/scripts/check-packages.sh" 2>&1); then
  printf 'package checker did not report a missing README binary\n' >&2
  exit 1
fi
case "$output" in
  *'missing: codex'*) ;;
  *) printf 'package checker missed an absent README binary\n' >&2; exit 1 ;;
esac
mv "$tmp_home/codex" "$apt_mock_bin/codex"
output=$(PATH="$apt_mock_bin" HOME="$tmp_home" BUN_INSTALL="$tmp_home/.bun" MISSING_PACKAGE=none \
  "$repo_dir/scripts/check-packages.sh")
case "$output" in
  *'All required packages and binaries are installed.'*) ;;
  *) printf 'package checker rejected a fully installed system\n' >&2; exit 1 ;;
esac
case "$output" in
  *'installed: bun 1.2.3'*'installed: composer Composer version 2.8.0'*'installed: safe-chain safe-chain 1.5.24'*) ;;
  *) printf 'package checker omitted installer-managed tool versions\n' >&2; exit 1 ;;
esac
for binary in zsh code nano codex bun phpvm php composer laravel git gh ssh rg btop htop sqlite3 chromium curl unzip safe-chain sentry-mcp; do
  case "$output" in
    *"installed: $binary "*) ;;
    *) printf 'package checker omitted README binary %s\n' "$binary" >&2; exit 1 ;;
  esac
done
mv "$apt_mock_bin/code" "$tmp_home/code"
output=$(PATH="$apt_mock_bin" HOME="$tmp_home" BUN_INSTALL="$tmp_home/.bun" MISSING_PACKAGE=none \
  "$repo_dir/scripts/check-packages.sh")
case "$output" in
  *'optional missing: code'*'All required packages and binaries are installed.'*) ;;
  *) printf 'package checker treated an optional binary as required\n' >&2; exit 1 ;;
esac

printf 'installer checks passed\n'
