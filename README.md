# Shellfish Terminal Toolkit

- **Version:** 1.0.0  
- **Author:** seinfold  
- **License:** MIT (see `LICENSE`)  
- **Credits:** Fish shell, GitHub CLI, zoxide, GNU screen, Bun completion contributors.

Shellfish bundles high-usability terminal tools so your Debian/Ubuntu console looks sharp and works smarter. In one guided run you get:

- A curated Fish experience (prompt, vi-mode tweaks, `gitget`, `repo_fuse`, `scr`, `screens`).
- SSH scaffolding with optional shortcuts and GitHub-aware defaults.
- Optional GitHub developer flow (GitHub username, dedicated `id_ed25519_github`, gh CLI reminder).
- Optional IRC toolkit (GNU screen + irssi) for persistent chats.
- Optional JetBrainsMono Nerd Font Light for crisp icons in Fish, VS Code, etc.

Shellfish keeps track of its changes. Re-running `./shellfish.sh` spots old backups and offers to restore everything before reinstalling with new settings.

---

## 1. Download the kit

```bash
git clone https://github.com/seinfold/shellfish.git ~/shellfish
cd ~/shellfish
chmod +x shellfish.sh
```

You can clone anywhere; using `~/shellfish` keeps the instructions simple.
## 2. Launch the installer

```bash
./shellfish.sh
```

During the guided install Shellfish asks:

1. **GitHub usage** – answer “yes” to configure gitget/repo_fuse, generate `id_ed25519_github`, and get a reminder to run `gh auth login`.  
2. **IRC helpers** – install GNU screen + irssi (required for the `scr` / `screens` helpers) or skip them.  
3. **Bash prompt** – whether to replace your existing `~/.bashrc` (Shellfish makes a timestamped backup before overwriting).  
4. **SSH shortcuts** – optionally import the sample `~/.ssh/config` and add your own `Host` aliases interactively.  
5. **JetBrainsMono Nerd Font Light** – download and install it locally so your terminal and editor show Nerd Font icons.

After the prompts Shellfish:
- Installs the requested CLI packages via `apt` (Fish, gh, zoxide, eza, tree, fzf, neofetch, unzip, screen/irssi if selected, etc.).  
- Copies Fish configuration (prompt, helpers, completions, manifest template).  
- Creates `~/.ssh`, optionally generates `id_ed25519_github`, and loads it with `ssh-add`.  
- Optionally installs JetBrainsMono Nerd Font Light into `~/.local/share/fonts` and refreshes the font cache.

## 3. Add the SSH key to GitHub (if you generated one)

```bash
cat ~/.ssh/id_ed25519_github.pub
```

Paste the single line into **GitHub → Settings → SSH and GPG keys → New SSH key**.

## 4. Authenticate GitHub CLI

```bash
gh auth login --hostname github.com --git-protocol ssh --web
```

Choose **SSH**, skip uploading a key (it’s already added), then follow the browser flow.

## 5. Restart the terminal

Open a fresh Fish session so universal variables, abbreviations, and the shellfish banner kick in.

## 6. Sanity checks

```fish
gitget --list            # repo.git lines from your GitHub account
gitget --pick            # numbered selection clone
gf --list                # repo_fuse manifest/GitHub listing
repo_fuse --source github --list   # requires GitHub configuration
screens                  # current screen sessions + usage help
scr demo log             # creates a logging screen session (detach with Ctrl-A D)
```

If `gitget` or `repo_fuse` fail, verify `ssh -T git@github.com` greets you with “Hi seinfold!”.

---

## Optional follow-ups
- Install project tooling you skipped (nodejs, npm, bun, build-essential, llvm, clang, Docker, VS Code, screen/irssi…).  
- Edit `~/.config/fish/repos/catalog.toml` to swap the sample entries for real repositories.  
- Customize `~/.config/fish/functions/gameserver.fish` with your own SSH shortcut.  
- Add `bind \\cs 'screens\\n'` to `config.fish` if you want <kbd>Ctrl</kbd>+<kbd>S</kbd> to open the screen chooser.

## Updating later

```bash
cd ~/shellfish
git pull
./shellfish.sh
```

Shellfish backs up existing files with timestamps before replacing them.

---

ASCII art credit: based on classic “><((°>” fish tweaked for Shellfish.
