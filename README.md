
# Shellfish Terminal Toolkit

- **Version:** 1.0.0
- **Author:** seinfold
- **License:** MIT (see `LICENSE`)
- **Credits:** Fish shell, GitHub CLI, zoxide, GNU screen, Bun completion contributors

Shellfish tunes your Debian/Ubuntu terminal in minutes. One guided session installs the essentials, locks in high-contrast fonts/icons, and leaves your shell tidy with backups.

![Shellfish terminal screenshot](https://github.com/seinfold/shellfish/raw/main/docs/shellfish-terminal.png "Shellfish terminal screenshot")

---

## What Shellfish installs

| Component | Purpose |
|-----------|---------|
| **fish shell** | Modern shell with Shellfish prompt, vi-mode indicator, IP banner, ASCII shellfish |
| **eza** | Fast, colourful replacement for `ls` with Git status and icons |
| **tree** | Recursive directory tree view for quick structure overviews |
| **fzf** | Fuzzy finder for history, files, and command output |
| **neofetch** | System summary banner (useful when sharing terminals/screens) |
| **zoxide** | `z` and `zi` smart directory jumping based on usage |
| **git** | Version control CLI used by Shellfish helpers |
| **curl** | HTTP utility used during setup and scripting |
| **wget** | Alternate download utility for environments without curl |
| **python3** | Runtime for repo_fuse/gitget helper scripts |
| **GNU screen** | Terminal multiplexer keeping long-running sessions alive |
| **irssi** *(optional)* | IRC client you can run inside screen |
| **gh** *(optional)* | GitHub CLI for repo listing and SSH auth checks |
| **unzip** | Required to unpack font archives |
| **JetBrainsMono Nerd Font Light** | Installed automatically so Fish icons render correctly (keep your terminal on this font or another Nerd Font) |

> Shellfish automatically installs JetBrainsMono Nerd Font Light. Switching your terminal to a non Nerd Font may hide file/folder glyphs.

---

## Shellfish customisations

| Helper | Location | Summary |
|--------|----------|---------|
| `gitget` (`gg`) | `~/.config/fish/functions/gitget.fish` | Lists GitHub repos as `name.git`, clone by name or index, numbered picker |
| `repo_fuse` (`gf` / `rf`) | `~/.config/fish/functions/repo_fuse.fish` | Clone + run manifest setup commands with logging/history |
| `scr` / `screens` | `~/.config/fish/functions/scr.fish`, `screens.fish` | Create/attach named GNU screen sessions with optional logging |
| Fish prompt/theme | `~/.config/fish/config.fish` | Custom prompt, vi-mode badge, colour scheme, ASCII shellfish greeting |
| SSH template | `~/.ssh/config` (optional) | GitHub entry + interactive shortcut builder |
| Repo manifest | `~/.config/fish/repos/catalog.toml` | Sample entries for `repo_fuse` |

Shellfish records every file it touches in `~/.local/share/shellfish/managed_files.txt`. Re-running `./shellfish.sh` spots existing backups and offers to roll everything back first.

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
2. **irssi** – choose whether to install the IRC client; if enabled you can pick a default network (ircnet/libera/oftc/efnet/custom).
3. **SSH shortcuts** – import the sample `~/.ssh/config` and add aliases like `ssh prod`.

Shellfish automatically replaces `~/.bashrc` (with a timestamped backup) and installs JetBrainsMono Nerd Font Light.

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
- Bind `Ctrl+S` to the screen list: `bind \cs 'screens\n'` in `config.fish`.
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
