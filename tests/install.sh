#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_home=$(mktemp -d)
trap 'rm -rf "$tmp_home"' 0
trap 'exit 1' HUP INT TERM
PHPVM_DIR="$tmp_home/.phpvm"
export PHPVM_DIR

printf 'old zsh config\n' > "$tmp_home/.zshrc"
printf 'old git config\n' > "$tmp_home/.gitconfig"
HOME="$tmp_home" "$repo_dir/scripts/symlink-dotfiles.sh"

[ "$(readlink "$tmp_home/.zshrc")" = "$repo_dir/.zshrc" ]
[ "$(readlink "$tmp_home/.gitconfig")" = "$repo_dir/.gitconfig" ]
set -- "$tmp_home"/.dotfiles-backup.*
[ -d "$1" ]
[ "$(cat "$1/.zshrc")" = 'old zsh config' ]
[ "$(cat "$1/.gitconfig")" = 'old git config' ]

HOME="$tmp_home" "$repo_dir/scripts/symlink-dotfiles.sh"
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
printf '%s\n' "$*" >> "${PHPVM_TEST_LOG:-/dev/null}"
if [ "${1:-}" = '--version' ]; then
  printf 'phpvm 1.0\n'
fi
EOF
cat > "$tmp_home/.config/composer/vendor/bin/laravel" <<'EOF'
#!/bin/sh
printf 'Laravel Installer 1.0\n'
EOF
cat > "$tmp_home/.bun/bin/sentry-mcp" <<'EOF'
#!/bin/sh
exit 0
EOF
for binary in zsh code nano codex php git gh ssh rg btop htop sqlite3 chromium unzip; do
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
  PHPVM_TEST_LOG="$tmp_home/phpvm-package.log" PACKAGE_TEST_LOG="$tmp_home/pacman.log" \
  "$repo_dir/scripts/install-packages.sh")
case "$output" in
  *'Aikido Safe Chain is already installed; skipping.'*'Bun is already installed; skipping.'*'PHPVM is already installed; skipping manager installation.'*'Composer is already installed; skipping.'*) ;;
  *) printf 'per-tool installers were not all run\n' >&2; exit 1 ;;
esac
[ "$(sed -n '1p' "$tmp_home/phpvm-package.log")" = 'install latest-remote' ]
[ "$(sed -n '2p' "$tmp_home/phpvm-package.log")" = 'use latest' ]
case "$(cat "$tmp_home/pacman.log")" in
  '-S --needed --noconfirm '*) ;;
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
for binary in zsh code nano codex php git gh ssh rg btop htop sqlite3 chromium unzip; do
  cp "$tmp_home/mock-bin/$binary" "$apt_mock_bin/$binary"
done
: > "$tmp_home/apt.log"
PATH="$apt_mock_bin" HOME="$tmp_home" BUN_INSTALL="$tmp_home/.bun" PACKAGE_TEST_LOG="$tmp_home/apt.log" \
  "$repo_dir/scripts/install-packages.sh"
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
for binary in zsh code nano codex bun phpvm php composer laravel git gh ssh rg btop htop sqlite3 chromium unzip safe-chain sentry-mcp; do
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
case "$output" in
  *'installed: curl '*|*'installed: wget '*)
    printf 'package checker still listed a bootstrap downloader\n' >&2
    exit 1
    ;;
esac

# A fresh PHPVM install must not append upstream shell setup to the user's Zsh config.
phpvm_home="$tmp_home/phpvm-home"
phpvm_mock_bin="$tmp_home/phpvm-mock-bin"
mkdir -p "$phpvm_home" "$phpvm_mock_bin"
printf 'keep this zsh config\n' > "$phpvm_home/.zshrc"
cat > "$phpvm_mock_bin/curl" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
  if [ "$1" = '-o' ]; then
    installer=$2
    break
  fi
  shift
done
cat > "$installer" <<'INSTALLER'
#!/bin/sh
[ "$PROFILE" != "$HOME/.zshrc" ] || exit 1
mkdir -p "$PHPVM_DIR/bin"
cat > "$PHPVM_DIR/bin/phpvm" <<'PHPVM'
#!/bin/sh
printf '%s\n' "$*" >> "$PHPVM_TEST_LOG"
PHPVM
chmod +x "$PHPVM_DIR/bin/phpvm"
printf 'upstream profile change\n' >> "$PROFILE"
INSTALLER
EOF
chmod +x "$phpvm_mock_bin/curl"
PATH="$phpvm_mock_bin:/usr/bin:/bin" HOME="$phpvm_home" PHPVM_DIR="$phpvm_home/.phpvm" \
  PHPVM_TEST_LOG="$phpvm_home/phpvm.log" "$repo_dir/scripts/installers/phpvm.sh"
[ "$(cat "$phpvm_home/.zshrc")" = 'keep this zsh config' ]
[ "$(sed -n '1p' "$phpvm_home/phpvm.log")" = 'install latest-remote' ]
[ "$(sed -n '2p' "$phpvm_home/phpvm.log")" = 'use latest' ]

# Installer downloads work when only wget is available.
download_bin="$tmp_home/download-bin"
mkdir -p "$download_bin"
cat > "$download_bin/wget" <<'EOF'
#!/bin/sh
if [ "$1" = '-qO' ] && [ "$3" = https://example.test/installer ]; then
  printf 'installer\n' > "$2"
elif [ "$1" = '-qO-' ] && [ "$2" = https://example.test/signature ]; then
  printf 'signature\n'
else
  exit 1
fi
EOF
chmod +x "$download_bin/wget"
(
  PATH="$download_bin"
  export PATH
  . "$repo_dir/scripts/download.sh"
  download_file https://example.test/installer "$tmp_home/downloaded"
  IFS= read -r downloaded < "$tmp_home/downloaded"
  [ "$downloaded" = installer ]
  [ "$(download_text https://example.test/signature)" = signature ]
)

# A fresh bootstrap installs Git, clones the repo, then installs packages and links configs.
bootstrap_git_mock="$tmp_home/bootstrap-git"
cat > "$bootstrap_git_mock" <<'GIT'
#!/bin/sh
[ "$1" = clone ] && [ "$2" = 'https://github.com/zainphp/.dotfiles.git' ] || exit 1
printf 'clone\n' >> "$BOOTSTRAP_MARKER"
mkdir -p "$3/.git" "$3/scripts"
cat > "$3/scripts/install-packages.sh" <<'PACKAGES'
#!/bin/sh
printf 'packages\n' >> "$BOOTSTRAP_MARKER"
PACKAGES
cat > "$3/scripts/symlink-dotfiles.sh" <<'LINKER'
#!/bin/sh
printf 'link\n' >> "$BOOTSTRAP_MARKER"
LINKER
chmod +x "$3/scripts/install-packages.sh" "$3/scripts/symlink-dotfiles.sh"
GIT

setup_bootstrap_bin() {
  target=$1
  package_manager=$2
  mkdir -p "$target"
  for utility in cat chmod cp mkdir; do
    ln -s "$(command -v "$utility")" "$target/$utility"
  done
  cat > "$target/id" <<'ID'
#!/bin/sh
printf '0\n'
ID
  cat > "$target/package-manager" <<'MANAGER'
#!/bin/sh
manager=${0##*/}
if [ "$manager" = apt-get ] && [ "$*" = update ]; then
  printf 'apt-update\n' >> "$BOOTSTRAP_MARKER"
  exit 0
fi
case "$manager:$*" in
  'pacman:-S --needed --noconfirm git'|'apt-get:install --yes git') ;;
  *) exit 1 ;;
esac
printf 'install-git\n' >> "$BOOTSTRAP_MARKER"
cp "$BOOTSTRAP_GIT_MOCK" "$BOOTSTRAP_BIN/git"
chmod +x "$BOOTSTRAP_BIN/git"
MANAGER
  chmod +x "$target/id" "$target/package-manager"
  ln -s package-manager "$target/$package_manager"
}

for package_manager in pacman apt-get; do
  bootstrap_home="$tmp_home/bootstrap-$package_manager-home"
  bootstrap_bin="$tmp_home/bootstrap-$package_manager-bin"
  mkdir -p "$bootstrap_home"
  setup_bootstrap_bin "$bootstrap_bin" "$package_manager"
  bootstrap_output=$(PATH="$bootstrap_bin" HOME="$bootstrap_home" \
    BOOTSTRAP_BIN="$bootstrap_bin" BOOTSTRAP_GIT_MOCK="$bootstrap_git_mock" \
    BOOTSTRAP_MARKER="$bootstrap_home/result" "$repo_dir/scripts/bootstrap.sh")
  if [ "$package_manager" = pacman ]; then
    [ "$(sed -n '1p' "$bootstrap_home/result")" = install-git ]
    next_step=2
  else
    [ "$(sed -n '1p' "$bootstrap_home/result")" = apt-update ]
    [ "$(sed -n '2p' "$bootstrap_home/result")" = install-git ]
    next_step=3
  fi
  [ "$(sed -n "${next_step}p" "$bootstrap_home/result")" = clone ]
  [ "$(sed -n "$((next_step + 1))p" "$bootstrap_home/result")" = packages ]
  [ "$(sed -n "$((next_step + 2))p" "$bootstrap_home/result")" = link ]
  case "$bootstrap_output" in
    *"$bootstrap_home/.dotfiles/scripts/restore.sh /path/to/backup.tar.gz"*) ;;
    *) printf 'bootstrap did not suggest the restore command\n' >&2; exit 1 ;;
  esac
  case "$bootstrap_output" in
    *"$bootstrap_home/.dotfiles/scripts/check-packages.sh"*) ;;
    *) printf 'bootstrap did not suggest checking packages\n' >&2; exit 1 ;;
  esac
done

conflict_home="$tmp_home/conflict-home"
mkdir -p "$conflict_home/.dotfiles"
printf 'keep\n' > "$conflict_home/.dotfiles/sentinel"
if PATH="$bootstrap_bin" HOME="$conflict_home" \
  BOOTSTRAP_BIN="$bootstrap_bin" BOOTSTRAP_GIT_MOCK="$bootstrap_git_mock" \
  BOOTSTRAP_MARKER="$conflict_home/result" "$repo_dir/scripts/bootstrap.sh" >/dev/null 2>&1; then
  printf 'bootstrap accepted a non-repository .dotfiles path\n' >&2
  exit 1
fi
[ "$(cat "$conflict_home/.dotfiles/sentinel")" = keep ]

printf 'installer checks passed\n'
