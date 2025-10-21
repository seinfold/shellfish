
# Shellfish Terminal Toolkit

- **Version:** 1.1.0
- **Author:** seinfold
- **License:** MIT (see `LICENSE`)
- **Credits:** Fish shell, eza, tree, fzf, neofetch, zoxide, GNU screen, irssi, GitHub CLI, JetBrainsMono Nerd Font (Nerd Fonts project), Bun completion contributors

Shellfish tunes your Debian/Ubuntu terminal in minutes. One guided session installs the essentials, locks in high-contrast fonts/icons, and leaves your shell tidy (with backups).

![Shellfish terminal screenshot](https://github.com/seinfold/shellfish/raw/main/docs/shellfish-terminal.png "Fish Terminal in action")

---

## What Shellfish installs

| Component | Purpose |
|-----------|---------|
| **fish shell** | Modern shell with custom modifications that you can tune to your likings |
| **eza** | Fast, colourful replacement for `ls` with Git status and icons |
| **tree** | Recursive directory tree view |
| **fzf** | Fuzzy finder for history, files, and command output |
| **neofetch** | System summary banner |
| **zoxide** | `z` and `zi` smart directory jumping |
| **git** | Version control CLI used by Shellfish helpers |
| **curl** | HTTP utility used during setup and scripting |
| **wget** | Alternate download utility for environments without curl |
| **python3** | Runtime for gitget helper script |
| **GNU screen** | Terminal multiplexer keeping long-running sessions alive |
| **irssi** *(optional)* | IRC client you can run inside screen |
| **gh** *(optional)* | GitHub CLI for quick repo listing and SSH auth checks |
| **unzip** | Required to unpack font archives |
| **JetBrainsMono Nerd Font Light** | Installed automatically so Fish icons render correctly (keep your terminal on this font or another Nerd Font) |

> Shellfish automatically installs JetBrainsMono Nerd Font Light. Switching your terminal to a non Nerd Font may hide file/folder graphic elements.

---


## Shellfish customisations

Quick reminders for the helpers Shellfish installs:

- **`gg` / `gitget`** – list or clone GitHub repositories.
  ```fish
  gg --list              # show repos as name.git
  gg my-repo.git         # clone by name
  gg 3                   # clone the third entry
  ```

- **`scr` / `screens`** – easy managing of GNU screen sessions.
  ```fish
  scr NAME               # opens screen NAME - use for game consoles / irc / development servers
  scr NAME log           # opens screen NAME - use for game consoles / irc / development servers with logging under ~/Documents/logs
  screens                # list all screens running that you can join with 'scr' or detach them with Ctrl-A → D
  ```
  
- **`irc`** – shortcut to IRC session with Irssi on a network of your choosing.
  ```fish
  irc                    # opens irc server connection, use with screen to keep chats open that you can return to
  ```

- **`stay <command>`** – run a command detached from the terminal (`nohup` wrapper).
- **`ls`** / **`treelist`** – aliased to `eza --icons` and `tree -a -I '.git'` for glyph-rich directory views.


---

## Quick start

```bash
git clone https://github.com/seinfold/shellfish.git ~/shellfish
cd ~/shellfish
chmod +x shellfish.sh
./shellfish.sh
```

### Optional installs

1. **GitHub support** – configure `gitget` with your username, optionally generate `~/.ssh/id_ed25519_github`, and remind you to run `gh auth login`. `gitget` can be used to list all your GitHub repositories easily and clone any of them to your computer.
1. **irssi** – choose whether to install the IRC client; if enabled you can pick a default network (ircnet/libera/oftc/efnet/custom).
1. **SSH shortcuts** – add aliases like `devserver` or `DEVSERVER` to immediately SSH to that server from your terminal.
   ```bash
    function devserver --description ' SSH into the Development Server '
        ssh -p 22 user@127.0.0.1 $argv
    end
    
    function DEVSERVER --description ' SSH into the Development server '
        devserver $argv
    end
   ```


Shellfish automatically replaces your `~/.bashrc` - but don't worry it will create backups that you can revert to by just running the script again.

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

3. **Open a fresh Fish terminal**

4. **Set a default GitHub user for gitget** (if you skipped it during setup):
   ```bash
   fish -c 'set -Ux GITGET_GITHUB_USER <username>'
   ```


---

## Optional follow-ups

- Customize `~/.config/fish/functions/gameserver.fish` with your favourite SSH shortcuts so you can connect to different server with just single word.
- Bind `Ctrl+S` to the screen list: `bind \cs 'screens\n'` in `config.fish`.

## Backups

Shellfish automatically backs up any file it changes with a timestamped `.bak`. When you rerun the installer it detects those backups and offers to restore the previous state before applying new settings.

---

ASCII art credit: based on classic “><((°>” fish tweaked for Shellfish.
