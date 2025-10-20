# Shellfish Terminal Toolkit

- **Version:** 1.0.0  
- **Author:** seinfold  
- **License:** MIT (see `LICENSE`)  
- **Credits:** Fish shell, GitHub CLI, zoxide, GNU screen, Bun completion contributors.

Shellfish is a portable bundle that recreates the Fish-based workflow (prompt, helpers, SSH setup, bootstrap script) on any Debian/Ubuntu-flavoured machine. Follow the steps below in order.

Re-running `./shellfish.sh` later will detect existing backups and offer to revert everything or reinstall with new settings.

---

## 1. Download the kit

```bash
git clone https://github.com/seinfold/shellfish.git ~/shellfish
cd ~/shellfish
chmod +x shellfish.sh
```

## 2. Launch the installer

```bash
./shellfish.sh
```

Shellfish remembers previous installs. If it spots backups from an earlier run, it offers to undo all Shellfish changes before continuing. During a fresh install it will ask:

1. **GitHub usage** – answer “yes” to configure gitget/repo_fuse, generate `id_ed25519_github`, and get a reminder to run `gh auth login`.  
2. **IRC helpers** – install GNU screen + irssi (required for the `scr` / `screens` helpers) or skip them.  
3. **Bash prompt** – whether to replace your existing `~/.bashrc` (Shellfish makes a timestamped backup before overwriting).  
4. **SSH shortcuts** – optionally import the sample `~/.ssh/config` and add your own `Host` aliases interactively.

After the prompts it:
- Installs the requested CLI packages via `apt`.  
- Copies Fish configuration (prompt, helpers, completions, manifest template).  
- Creates `~/.ssh`, optionally generates `id_ed25519_github`, and loads it with `ssh-add`.  
- Leaves behind clear next steps (GitHub login, repo manifest tweaks, verification commands).

## 3. Add the SSH key to GitHub (only if you generated a new one)

```bash
cat ~/.ssh/id_ed25519_github.pub
```

Copy the single line into **GitHub → Settings → SSH and GPG keys → New SSH key**.

## 4. Authenticate GitHub CLI

```bash
gh auth login --hostname github.com --git-protocol ssh --web
```

Pick **SSH**, skip uploading a key (it’s already added), choose the browser flow, paste the code.

## 5. Restart the terminal

Open a fresh Fish session so universal variables, abbreviations, and the little ASCII shellfish banner appear.

## 6. Sanity checks

```fish
gitget --list            # repo.git lines from your account
gitget --pick            # numbered selection clone
gf --list                # repo_fuse manifest/GitHub listing
repo_fuse --source github --list   # requires GitHub configuration
screens                  # current screen sessions + usage help
scr demo log             # creates a logging screen session (detach with Ctrl-A D)
```

If `gitget` or `repo_fuse` fail, verify `ssh -T git@github.com` greets you with your username (or re-run `shellfish.sh` and answer “yes” to the GitHub prompt).

---

## Optional follow-ups
- Install project-specific tooling (nodejs, npm, bun, build-essential, llvm, clang, Docker, VS Code, …). If you skipped screen/irssi earlier, install them before using `scr` / `screens`.  
- Edit `~/.config/fish/repos/catalog.toml` to swap the sample entries for real repositories.  
- Customize `~/.config/fish/functions/gameserver.fish` with a shortcut of your own.  
- Add `bind \cs 'screens\n'` to your `config.fish` if you want <kbd>Ctrl</kbd>+<kbd>S</kbd> to show the `screens` helper.

## Updating later
When configs change, rerun:

```bash
cd ~/shellfish
git pull
./shellfish.sh
```

The script backs up existing files with timestamps before replacing them.

---

ASCII art credit: based on classic “><((°>” fish tweaked for Shellfish.
