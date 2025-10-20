# Shellfish Terminal Toolkit

- **Version:** 1.0.0
- **Author:** seinfold
- **License:** MIT (see `LICENSE`)
- **Credits:** Fish shell, GitHub CLI, zoxide, GNU screen, Bun completion contributors

Shellfish tunes your Debian/Ubuntu terminal in minutes. One guided session installs the essentials, offers optional developer helpers, and leaves your shell tidy with backups.

---

## What Shellfish installs

| Component | Purpose |
|-----------|---------|
| **fish shell** | Modern shell with Shellfish prompt, vi-mode indicator, greeting banner |
| **eza**, **tree**, **fzf**, **neofetch** | Enhanced listing, directory trees, fuzzy search, system summary |
| **zoxide** | `z` / `zi` smart directory jumps |
| **git**, **curl**, **wget**, **python3** | Base developer tooling required by the helpers |
| **GNU screen** *(optional)* | Persistent terminal windows for servers, monitoring, long-running tasks |
| **irssi** *(optional)* | IRC client (runs nicely inside screen but optional at the same prompt) |
| **gh** *(optional)* | GitHub CLI for repo listing/auth |
| **unzip** | Needed to unpack optional fonts |
| **JetBrainsMono Nerd Font Light** *(optional)* | Nerd-font glyph support for your terminal/editor |

Every package installs via `apt`. GitHub, screen, irssi, and fonts are only installed when you explicitly confirm their prompts.

---

## Shellfish customizations

| Helper | Location | Summary |
|--------|----------|---------|
| `gitget` (`gg`) | `~/.config/fish/functions/gitget.fish` | Lists GitHub repos as `name.git`, clone by name or index, numbered picker |
| `repo_fuse` (`gf` / `rf`) | `~/.config/fish/functions/repo_fuse.fish` | Clone + run manifest setup commands with logging/history |
| `scr` / `screens` | `~/.config/fish/functions/scr.fish`, `screens.fish` | Create/attach named GNU screen sessions with optional logging |
| Fish prompt/theme | `~/.config/fish/config.fish` | Custom prompt, vi-mode badge, color scheme, ASCII shellfish greeting |
| SSH template | `~/.ssh/config` (optional) | GitHub entry + interactive shortcut builder |
| Repo manifest | `~/.config/fish/repos/catalog.toml` | Sample entries for `repo_fuse` |

Shellfish records every file it touches in `~/.local/share/shellfish/managed_files.txt`. If you run it again, it spots existing backups and offers to roll everything back first.

---

## Quick start

```bash
git clone https://github.com/seinfold/shellfish.git ~/shellfish
cd ~/shellfish
chmod +x shellfish.sh
./shellfish.sh
```

### During setup you will be asked about

1. **GitHub support** – configure `gitget`/`repo_fuse` with your username, optionally generate `~/.ssh/id_ed25519_github`, and remind you to run `gh auth login`.
2. **GNU screen** – install the terminal multiplexer used by `scr`/`screens` for detached sessions.
3. **irssi** – optional IRC client if you plan to chat from screen while the session manager is already installed.
4. **Shell prompt** – optionally replace `~/.bashrc` (Shellfish backs up the original to `.bashrc.<timestamp>.bak`).
5. **SSH shortcuts** – import the sample `~/.ssh/config` and add aliases like `ssh prod`.
6. **JetBrainsMono Nerd Font Light** – download to `~/.local/share/fonts/JetBrainsMonoNerd` and refresh `fc-cache`.

If backups from a previous run exist, Shellfish offers to restore everything before continuing.

---

## After installation

1. **Add your GitHub key** (if generated):
   ```bash
   cat ~/.ssh/id_ed25519_github.pub
   ```
   Paste into GitHub → Settings → SSH and GPG keys.

2. **Authenticate GitHub CLI** (if enabled):
   ```bash
   gh auth login --hostname github.com --git-protocol ssh --web
   ```

3. **Open a fresh Fish terminal** to load prompts, abbreviations, and the Shellfish banner.

4. **Sanity check helpers**:
   ```fish
   gitget --list            # repo.git lines from GitHub (requires GitHub configuration)
   gitget --pick            # numbered selection clone
   gf --list                # repo_fuse manifest/GitHub listing
   repo_fuse --source github --list   # requires GitHub configuration
   screens                  # list screen sessions + usage hints
   scr demo log             # create a logging screen session (Ctrl-A D to detach)
   ```

---

## Optional follow-ups

- Replace the manifest entries in `~/.config/fish/repos/catalog.toml` with your real projects.
- Customize `~/.config/fish/functions/gameserver.fish` with your favourite SSH shortcut.
- Bind `Ctrl+S` to the screen list: `bind \\cs 'screens\\n'` in `config.fish`.
- Install other tooling you skipped (Node.js, bun, Docker, VS Code, etc.).

## Updating later

```bash
cd ~/shellfish
git pull
./shellfish.sh
```

Shellfish always backs up existing files before replacing them, and it can restore those backups on demand.

---

ASCII art credit: based on classic “><((°>” fish tweaked for Shellfish.
