# Shellfish Deployment and Operations Manual

## 1. Overview

Shellfish provisions a Fish shell workstation profile with predefined command-line tooling and helper scripts on Debian or Ubuntu hosts. This document provides the installation workflow, a list of installed components, primary usage patterns, maintenance notes, and removal steps.

---

## 2. Installation

### 2.1 Prerequisites
- Debian or Ubuntu system with sudo access
- Git client
- Network access for package repositories and GitHub assets

### 2.2 Acquire sources
```bash
git clone https://github.com/seinfold/shellfish.git ~/shellfish
cd ~/shellfish
chmod +x shellfish.sh
```

### 2.3 Execute installer
- Standard deployment:
  ```bash
  ./shellfish.sh
  ```
- Dry-run (no modifications):
  ```bash
  ./shellfish.sh --dry-run
  ```

Prompts appear for:
1. GitHub integration (SSH key, gh authentication reminder)
2. Optional installation of irssi and default network selection
3. Optional SSH shortcut collection

Each file touched receives a timestamped `.bak` backup alongside the original.

---

## 3. First-Run Actions

| Activity | Command |
|----------|---------|
| Confirm GitHub key (if GitHub support enabled) | `ls ~/.ssh/id_ed25519_github` |
| Register key with GitHub | `cat ~/.ssh/id_ed25519_github.pub` → GitHub → Settings → SSH and GPG keys |
| Authenticate GitHub CLI | `gh auth login --hostname github.com --git-protocol ssh --web` |
| Set gitget default user (if skipped) | `fish -c 'set -Ux GITGET_GITHUB_USER <username>'` |
| Start a new Fish session to load configuration | `fish` |

---

## 4. Installed Components

| Component | Purpose | Notes |
|-----------|---------|-------|
| Fish shell | Interactive shell environment | Vi keybindings enabled |
| gitget | GitHub repository discovery / clone helper | Uses `gh` |
| ssh_shortcuts | Fish wrappers for SSH hosts | Generated during install |
| PATH bootstrap | Adds common user bin directories to Fish PATH | `fish/conf.d/99-shellfish-paths.fish` |
| scr / screens | GNU screen wrappers | Logging variant supported |
| fzf | Fuzzy selection utility | Integrated with Fish history |
| zoxide | Directory jump database | `z` and `zi` commands |
| eza | Replacement for `ls` | Icons enabled |
| tree | Recursive directory listing | Available via `treelist` alias |
| neofetch | System summary output | `neofetch` |
| gh (optional) | GitHub CLI | Installed when GitHub support chosen |
| irssi (optional) | IRC client | Installed when selected |
| screen | Terminal multiplexer | Required by `scr` helpers |
| Python 3 toolchain | `python3`, `python3-pip`, `python3-venv` | Supports helper scripts |
| curl / wget | Download utilities | Used during setup |
| unzip | Required for font extraction | |
| JetBrainsMono Nerd Font | Icon support | Install performed automatically |

Packages installed via apt:
```
fish git curl wget python3 python3-pip python3-venv \
eza tree zoxide fzf neofetch unzip screen
```
Optional additions: `gh`, `irssi`.

---

## 5. Shellfish Helpers

### 5.1 gitget
```fish
gitget --list                  # list repositories
gitget --pick                  # numbered selection
gitget repo-name               # clone repo-name.git into ./repo-name
gitget 4                       # clone entry at index 4
```
Requirements: `gh auth status` passes; `GITGET_GITHUB_USER` set or obtainable.

### 5.2 SSH shortcuts
Artifacts:
- `~/.ssh/config`
- `~/.config/fish/functions/ssh_shortcuts.fish`

Usage:
```fish
prod             # execute ssh using host "prod"
PROD uptime      # uppercase variant forwards to lowercase function
```

Add new entries by rerunning the installer or editing the files directly.

### 5.3 screen wrappers
```fish
scr build        # create/attach session "build"
scr build log    # create session with logging enabled
screens          # list sessions
```

### 5.4 IRC helper (if installed)
```fish
irssi -c libera  # manual invocation
irc              # uses configured default network
```
Core irssi commands: `/connect`, `/join`, `/msg`, `/nick`, `/quit`.

---

## 6. Working in Fish

Enabled features:
- `fish_vi_key_bindings`
- `kj` exits insert mode
- Prompt shows current directory and arrow
- Environment paths appended for pnpm, bun, zoxide, Rust (if detected)
- Automatic sourcing of `ssh_shortcuts.fish`

Useful commands:
```fish
functions | grep ssh
abbr -l
set -U
fish_update_completions
```

---

## 7. Navigation Utilities

### 7.1 fzf
```fish
history | fzf
rg pattern | fzf --height 20
```

### 7.2 zoxide
```fish
z project        # jump to frequently used directory matching "project"
zi               # interactive selector
```

### 7.3 eza and tree
```fish
ls --git
ls -lhg --icons
treelist
```

---

## 8. Maintenance

### 8.1 Re-run installer
```bash
cd ~/shellfish
git pull
./shellfish.sh
```
Use `--dry-run` if unsure about local edits.

### 8.2 Restore modified files
- Invoke installer
- Accept restoration when `.bak` files detected
- Rerun installation if current configuration should be applied afterward

### 8.3 Font refresh
Rerun installer to reinstall JetBrains Mono Nerd Font. Update terminal profile to use the font if required.

---

## 9. Troubleshooting

| Symptom | Diagnostic | Resolution |
|---------|------------|------------|
| `gitget: gh repo list failed` | `gh auth status` | Re-authenticate `gh`, ensure token with repo scope |
| SSH shortcut missing | `test -f ~/.config/fish/functions/ssh_shortcuts.fish` | Source file or regenerate via installer |
| Fish not default shell | `echo $SHELL` | `chsh -s $(command -v fish)` and log out/in |
| Glyphs absent | Terminal font not set | Select “JetBrainsMono Nerd Font” |
| Stale screen session | `screen -ls` | `screen -S <name> -X quit` |
| `z` command absent | Path not updated | Restart session or verify `fish_add_path` entries |

---

## 10. Removal

1. Run the installer and select the restore option to reinstate `.bak` files.
2. Remove state directory if desired: `rm -rf ~/.local/share/shellfish`.
3. Revert shell: `chsh -s /bin/bash` (or preferred shell).
4. Remove packages installed by Shellfish:
   ```bash
   sudo apt-get remove --purge fish git curl wget python3 python3-pip python3-venv \
     eza tree zoxide fzf neofetch unzip screen gh irssi
   sudo apt-get autoremove
   ```
   Remove `gh` and `irssi` from the command if they were not installed.

Backups remain alongside original files (`filename.YYYYMMDD-HHMMSS.bak`). Validate before deletion.

---

## 11. Quick Reference

| Task | Command |
|------|---------|
| GitHub CLI login | `gh auth login --hostname github.com --git-protocol ssh --web` |
| Load new SSH key into agent | `ssh-add ~/.ssh/id_ed25519_github` |
| Fish configuration utility | `fish_config` |
| Refresh font cache | `fc-cache -fv ~/.local/share/fonts` |
| System package update | `sudo apt-get update && sudo apt-get upgrade` |

---

Shellfish can be customized further by editing the installed Fish functions or rerunning the installer as requirements change.
