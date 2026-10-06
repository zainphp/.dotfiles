# Dotfiles

Portable Linux shell and Git settings for Arch and Debian/Ubuntu.

Fresh install with curl:

```sh
curl -fsSL https://raw.githubusercontent.com/zainphp/.dotfiles/main/scripts/bootstrap.sh | sh
```

Or with wget:

```sh
wget -qO- https://raw.githubusercontent.com/zainphp/.dotfiles/main/scripts/bootstrap.sh | sh
```

Check packages after installation:

```sh
"$HOME/.dotfiles/scripts/check-packages.sh"
```

The bootstrap installs Git if needed, clones this repository, installs packages from the [Arch](packages/arch.txt) or [Debian/Ubuntu](packages/debian.txt) list, then replaces existing `~/.zshrc` and `~/.gitconfig` files with links into the repo. Package installation may prompt for `sudo`.

The package installer sets up PHPVM, selects its newest available PHP version, then installs Composer. Oh My Zsh and Bun load from their usual `$HOME` locations. VS Code is preferred when `code` is available; otherwise the editor is Nano.

GitHub authentication uses GitHub CLI (`gh auth login`). Keep credentials and private keys outside this repository.

For local environment variables, add exports to the ignored `.zshrc.local` file. It is sourced by `.zshrc` and is not committed.

In a trusted project, run `project-path` from its root to add existing `node_modules/.bin` and `vendor/bin` directories to the current shell's `PATH`.

## Apps

### Shell and editors

- [Zsh](https://zsh.sourceforge.io/) with optional [Oh My Zsh](https://ohmyz.sh/) `git`, `gh`, and `bun` plugins plus [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions).
- [Visual Studio Code](https://code.visualstudio.com/docs) and [Nano](https://www.nano-editor.org/docs.php).

### AI and agent tools

- [Codex CLI](https://github.com/openai/codex) · [official docs](https://learn.chatgpt.com/docs/codex/cli)
  - Personal skills: `bun`, `code-simplifier`, `find-skills`, and `refactor`.
  - Codex system skills: `imagegen`, `openai-docs`, `review-agent`, `skill-creator`, and `skill-installer`.
  - Installed plugin: [Ponytail 4.13.0](https://github.com/DietrichGebert/ponytail) (the only locally listed plugin reported installed and enabled). Its skills are `ponytail`, `ponytail-audit`, `ponytail-debt`, `ponytail-gain`, `ponytail-help`, and `ponytail-review`. See the [Codex skills](https://developers.openai.com/plugins/concepts/skills) and [plugin](https://developers.openai.com/plugins/concepts/plugins) docs.

### Development tools and runtimes

- [Bun](https://bun.com/docs) is the main JavaScript runtime and package manager.
  - Global package: [`@sentry/mcp-server`](https://github.com/getsentry/sentry-mcp).
- [PHP](https://www.php.net/) with [phpvm](https://github.com/Thavarshan/phpvm).
- [Composer](https://getcomposer.org/doc/) manages PHP packages.
  - Global package: [`laravel/installer`](https://packagist.org/packages/laravel/installer).

### System and source-control tools

- [Git](https://git-scm.com/doc), [GitHub CLI](https://cli.github.com/manual/), [OpenSSH](https://www.openssh.com/), and [ripgrep](https://github.com/BurntSushi/ripgrep).
- [btop](https://github.com/aristocratos/btop) and [SQLite CLI](https://www.sqlite.org/cli.html).
- [UnZip](https://infozip.sourceforge.net/UnZip.html).
- [Aikido Safe Chain](https://github.com/AikidoSec/safe-chain).

## Private files to preserve

Keep these out of Git. `./scripts/backup.sh` archives these locations; the archive contains private data, so store it somewhere private.

- `~/.ssh/` — SSH keys and configuration.
- `~/projects/` — source files, uncommitted work, ignored files, and project `.env` files.
- `~/.codex/sessions/`, `~/.codex/memories/`, `~/.codex/*.jsonl`, and `~/.codex/*.sqlite*` — Codex sessions, memories, JSONL records, and databases. Close Codex before backing up.
- `~/.dotfiles/.zshrc.local` — local shell exports; this file is Git-ignored and included in the dotfiles archive.
- Zsh command log — saved from the home directory.

Do not commit `.env` files, private keys, or login tokens. `scripts/backup.sh` excludes `~/.codex/auth.json`; sign in again with Codex and `gh auth login` after reinstalling.

Run `./scripts/backup.sh` before reinstalling Linux. It saves projects, SSH keys, Zsh state, this dotfiles repo (including `.zshrc.local`), and Codex sessions and memories to the ignored `./backups/` directory and prints the archive's full path. Pass another destination directory or set `DOTFILES_BACKUP_DIR` to use a mounted drive for reinstall backups. Close Codex first. The archive contains private keys, shell records, and project data; keep it private. Reinstallable Codex packages/plugins, temporary files, and `auth.json` are excluded.

Restore the newest archive with `./scripts/restore.sh`; pass an archive path to choose a specific backup. The script asks before restoring because existing files may be overwritten; use `--yes` to confirm non-interactively.
