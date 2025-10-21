#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SHELLFISH_VERSION="1.1.0"

SHELLFISH_ASCII="$(cat <<'EOF'
      __
  ><((__o   shellfish
      )     terminal toolkit by Tero Civill 2025
     ((
EOF
)"

STATE_DIR="$HOME/.local/share/shellfish"
MANIFEST_FILE="$STATE_DIR/managed_files.txt"
SHELLFISH_BASHRC="$STATE_DIR/bashrc"
SHELLFISH_SNIPPET_START="# >>> shellfish >>>"
SHELLFISH_SNIPPET_END="# <<< shellfish <<<"
declare -a MANAGED_PATHS=()
DEFAULT_PATHS=(
  "$HOME/.config/fish/config.fish"
  "$HOME/.config/fish/functions/gitget.fish"
  "$HOME/.config/fish/functions/repo_fuse.fish"
  "$HOME/.config/fish/functions/gameserver.fish"
  "$HOME/.config/fish/functions/scr.fish"
  "$HOME/.config/fish/functions/screens.fish"
  "$HOME/.config/fish/conf.d/repo_fuse.fish"
  "$HOME/.config/fish/conf.d/fnm.fish"
  "$HOME/.config/fish/conf.d/rustup.fish"
  "$HOME/.config/fish/completions/bun.fish"
  "$HOME/.config/fish/repos/catalog.toml"
  "$HOME/.bashrc"
  "$SHELLFISH_BASHRC"
  "$HOME/.ssh/config"
)

info()  { printf "\033[1;34m[info]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[err ]\033[0m %s\n" "$*"; }

normalize_answer() {
  local ans="${1:-}"
  ans="${ans,,}"
  if [[ -z "$ans" || "$ans" == "y" || "$ans" == "yes" ]]; then printf "y"; else printf "n"; fi
}

contains_path() {
  local candidate="$1"
  local path
  for path in "${MANAGED_PATHS[@]}"; do
    [[ "$path" == "$candidate" ]] && return 0
  done
  return 1
}

add_known_path() {
  local candidate="$1"
  contains_path "$candidate" || MANAGED_PATHS+=("$candidate")
}

record_managed_path() {
  local candidate="$1"
  add_known_path "$candidate"
  mkdir -p "$STATE_DIR"
  if [[ -f "$MANIFEST_FILE" ]]; then
    grep -Fxq "$candidate" "$MANIFEST_FILE" || echo "$candidate" >> "$MANIFEST_FILE"
  else
    echo "$candidate" > "$MANIFEST_FILE"
  fi
}

ensure_state() {
  MANAGED_PATHS=()
  mkdir -p "$STATE_DIR"
  if [[ -f "$MANIFEST_FILE" ]]; then
    while IFS= read -r line; do [[ -n "$line" ]] && add_known_path "$line"; done < "$MANIFEST_FILE"
  fi
  local path
  for path in "${DEFAULT_PATHS[@]}"; do add_known_path "$path"; done
}

has_shellfish_backups() {
  shopt -s nullglob
  local file backups
  for file in "${MANAGED_PATHS[@]}"; do
    backups=( "${file}".*.bak )
    if ((${#backups[@]})); then shopt -u nullglob; return 0; fi
  done
  shopt -u nullglob
  return 1
}

restore_shellfish() {
  local file latest restored=0
  shopt -s nullglob
  for file in "${MANAGED_PATHS[@]}"; do
    local backups=( "${file}".*.bak )
    if ((${#backups[@]})); then
      latest="$(printf '%s\n' "${backups[@]}" | sort -r | head -n1)"
      mkdir -p "$(dirname "$file")"
      cp -f "$latest" "$file"
      info "Restored $file from $(basename "$latest")"
      restored=1
    else
      info "No backup for $file; leaving as-is."
    fi
  done
  shopt -u nullglob
  if (( restored )); then
    rm -f "$MANIFEST_FILE"
    info "Restoration complete. Backups remain on disk."
  else
    warn "No Shellfish changes found to restore."
  fi
  return $restored
}

install_nerd_font() {
  local fonts_root="$HOME/.local/share/fonts"
  local fonts_dir="$fonts_root/JetBrainsMonoNerd"
  local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  local tmp_dir archive

  tmp_dir=$(mktemp -d) || return 1
  archive="$tmp_dir/JetBrainsMono.zip"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$archive" || { warn "Downloading Nerd Font archive failed."; rm -rf "$tmp_dir"; return 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$archive" || { warn "Downloading Nerd Font archive failed."; rm -rf "$tmp_dir"; return 1; }
  else
    warn "Neither curl nor wget available; cannot download Nerd Font."; rm -rf "$tmp_dir"; return 1
  fi

  mkdir -p "$fonts_dir"
  unzip -o "$archive" -d "$fonts_dir" >/dev/null || { warn "Unzipping Nerd Font archive failed."; rm -rf "$tmp_dir"; return 1; }
  rm -rf "$tmp_dir"

  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$fonts_root" >/dev/null 2>&1 || warn "fc-cache refresh failed; run 'fc-cache -fv ~/.local/share/fonts' manually."
  else
    warn "fc-cache not found; run 'fc-cache -fv ~/.local/share/fonts' to refresh fonts."
  fi

  info "JetBrainsMono Nerd Font installed under $fonts_dir. Set it to be used in your terminal."
  record_managed_path "$fonts_dir"
  return 0
}

copy_file() {
  local src="$1"
  local dest="$2"
  local mode="${3:-0644}"

  [[ -f "$src" ]] || { error "Missing source file: $src"; exit 1; }

  local dest_dir rp
  dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir"

  if [[ -e "$dest" && ! -L "$dest" && ! -d "$dest" ]]; then
    local backup="${dest}.${TIMESTAMP}.bak"
    cp -f "$dest" "$backup"
    if rp="$(readlink -f "$dest" 2>/dev/null)"; then :; else rp="$dest"; fi
    info "Backed up existing $rp → $backup"
  fi

  install -m "$mode" "$src" "$dest"
  info "Installed $(basename "$src") → $dest"
  record_managed_path "$dest"
}

ensure_package_apt() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    sudo apt-get install -y "$pkg"
  fi
}

ensure_gh_on_apt() {
  if dpkg -s gh >/dev/null 2>&1; then return 0; fi
  info "Installing GitHub CLI repo…"
  sudo apt-get install -y ca-certificates curl >/dev/null 2>&1 || true
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null 2>&1 || true
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y gh
}

ensure_packages() {
  local packages=("$@")
  if command -v apt-get >/dev/null 2>&1; then
    info "Updating package index…"
    sudo apt-get update
    local pkg
    for pkg in "${packages[@]}"; do
      if [[ "$pkg" == "gh" ]]; then ensure_gh_on_apt || warn "Could not install gh automatically."
      else info "Installing $pkg…"; ensure_package_apt "$pkg" || warn "Could not install $pkg automatically."
      fi
    done
  else
    warn "Unsupported package manager. Install manually: ${packages[*]}"
  fi
}

start_ssh_agent_if_needed() {
  if ! ssh-add -l >/dev/null 2>&1; then
    eval "$(ssh-agent -s)" >/dev/null
  fi
}

fish_set_universal() {
  # $1 = var name, $2 = value
  command -v fish >/dev/null 2>&1 || return 0
  # Pass value as argv[1] to avoid quoting pitfalls
  fish -c 'set -Ux -- $argv[1] $argv[2]' -- "$1" "$2" || return 1
}

ensure_bashrc_snippet() {
  local target="$HOME/.bashrc"
  local snippet_file="$SHELLFISH_BASHRC"
  local resolved

  if [[ -f "$target" ]]; then
    if grep -Fq "$SHELLFISH_SNIPPET_START" "$target"; then
      info "Shellfish snippet already present in $target"
    else
      local backup="${target}.${TIMESTAMP}.bak"
      cp -f "$target" "$backup"
      if resolved="$(readlink -f "$target" 2>/dev/null)"; then :; else resolved="$target"; fi
      info "Backed up existing $resolved → $backup"
      {
        printf '\n%s\n' "$SHELLFISH_SNIPPET_START"
        printf '%s\n' "# Added by shellfish to load its Bash helpers."
        printf '%s\n' "if [ -f \"$snippet_file\" ]; then"
        printf '%s\n' "  . \"$snippet_file\""
        printf '%s\n\n' "$SHELLFISH_SNIPPET_END"
      } >> "$target"
      info "Appended Shellfish snippet to $target"
    fi
  else
    cat <<EOF > "$target"
# ~/.bashrc
# Created by shellfish on $TIMESTAMP

$SHELLFISH_SNIPPET_START
# Added by shellfish to load its Bash helpers.
if [ -f "$snippet_file" ]; then
  . "$snippet_file"
fi
$SHELLFISH_SNIPPET_END
EOF
    chmod 0644 "$target"
    info "Created $target with Shellfish snippet."
  fi

  record_managed_path "$target"
}

main() {
  local dry_run="n"
  if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run="y"
    info "Dry run mode. No changes will be made."
  fi

  printf "\n%s\n\n" "$SHELLFISH_ASCII"
  info "Shellfish v${SHELLFISH_VERSION} — prepping your Fish terminal environment."

  ensure_state

  local previous_state="n"
  if has_shellfish_backups || [[ -f "$MANIFEST_FILE" ]]; then previous_state="y"; fi

  if [[ "$previous_state" == "y" ]]; then
    echo
    echo "Shellfish state detected."
    if has_shellfish_backups; then
      read -rp "Revert Shellfish changes using available backups? [y/N] " revert_ans
      if [[ "$(normalize_answer "$revert_ans")" == "y" ]]; then
        if [[ "$dry_run" == "n" ]]; then
          if restore_shellfish; then
            ensure_state
            info "Shellfish settings reverted."
          fi
        else
          info "Dry run: would restore backups."
        fi
        read -rp "Run Shellfish setup again with fresh settings? [Y/n] " rerun_after_restore
        if [[ "$(normalize_answer "$rerun_after_restore")" != "y" ]]; then
          info "Exiting."
          printf "\n%s\n" "$SHELLFISH_ASCII"
          return 0
        fi
      else
        read -rp "Proceed with installation without reverting? [Y/n] " proceed_ans
        if [[ "$(normalize_answer "$proceed_ans")" != "y" ]]; then
          info "Exiting."
          printf "\n%s\n" "$SHELLFISH_ASCII"
          return 0
        fi
      fi
    else
      read -rp "Shellfish state found. Run setup again with new settings? [Y/n] " rerun_only
      if [[ "$(normalize_answer "$rerun_only")" != "y" ]]; then
        info "Exiting."
        printf "\n%s\n" "$SHELLFISH_ASCII"
        return 0
      fi
    fi
  fi

  echo
  read -rp "Do you use GitHub for development? [Y/n] " answer
  local use_github; use_github="$(normalize_answer "$answer")"

  echo
  echo "Shellfish ships GNU screen by default; optionally add irssi for chat."
  local install_irc="n"
  read -rp "Install irssi (IRC client)? [Y/n] " answer
  install_irc="$(normalize_answer "$answer")"

  echo
  echo "JetBrainsMono Nerd Font is required for icons and will be installed automatically."
  local install_font="y"

  local irc_network="ircnet"
  if [[ "$install_irc" == "y" ]]; then
    echo
    echo "Choose default irssi network (for 'irssi -c <network>')."
    echo "  1) ircnet"
    echo "  2) libera"
    echo "  3) oftc"
    echo "  4) efnet"
    echo "  5) Custom"
    read -rp "Selection [1]: " choice
    case "${choice:-1}" in
      2) irc_network="libera" ;;
      3) irc_network="oftc" ;;
      4) irc_network="efnet" ;;
      5) read -rp "Enter custom irssi network name: " custom_net; [[ -n "${custom_net:-}" ]] && irc_network="$custom_net" ;;
      *) irc_network="ircnet" ;;
    esac
  fi

  local packages=(
    fish git curl wget python3 python3-pip python3-venv
    eza tree zoxide fzf neofetch unzip screen
  )
  if [[ "$use_github" == "y" ]]; then packages+=(gh); fi
  if [[ "$install_irc" == "y" ]]; then packages+=(irssi); fi

  if [[ "$dry_run" == "n" ]]; then
    ensure_packages "${packages[@]}"
  else
    info "Dry run: would install packages: ${packages[*]}"
  fi

  if [[ "$dry_run" == "n" ]]; then
    install_nerd_font || warn "JetBrainsMono Nerd Font installation encountered issues."
  else
    info "Dry run: would install JetBrainsMono Nerd Font to ~/.local/share/fonts."
  fi

  if [[ "$dry_run" == "n" ]]; then
    mkdir -p "$HOME/.config/fish"/{functions,conf.d,completions,repos}
    mkdir -p "$HOME/.local/share/repo-fuse/logs"

    copy_file "$SCRIPT_DIR/fish/config.fish" "$HOME/.config/fish/config.fish"
    copy_file "$SCRIPT_DIR/fish/functions/gitget.fish" "$HOME/.config/fish/functions/gitget.fish"
    copy_file "$SCRIPT_DIR/fish/functions/repo_fuse.fish" "$HOME/.config/fish/functions/repo_fuse.fish"
    copy_file "$SCRIPT_DIR/fish/functions/gameserver.fish" "$HOME/.config/fish/functions/gameserver.fish"
    copy_file "$SCRIPT_DIR/fish/functions/scr.fish" "$HOME/.config/fish/functions/scr.fish"
    copy_file "$SCRIPT_DIR/fish/functions/screens.fish" "$HOME/.config/fish/functions/screens.fish"
    copy_file "$SCRIPT_DIR/fish/conf.d/repo_fuse.fish" "$HOME/.config/fish/conf.d/repo_fuse.fish"
    copy_file "$SCRIPT_DIR/fish/conf.d/fnm.fish" "$HOME/.config/fish/conf.d/fnm.fish"
    copy_file "$SCRIPT_DIR/fish/conf.d/rustup.fish" "$HOME/.config/fish/conf.d/rustup.fish"
    copy_file "$SCRIPT_DIR/fish/completions/bun.fish" "$HOME/.config/fish/completions/bun.fish"
    copy_file "$SCRIPT_DIR/fish/repos/catalog.toml" "$HOME/.config/fish/repos/catalog.toml"
  else
    info "Dry run: would copy Fish configuration files."
  fi

  if [[ "$dry_run" == "n" ]]; then
    if command -v fish >/dev/null 2>&1; then
      if fish_set_universal "SHELLFISH_IRC_NETWORK" "$irc_network"; then
        info "Set SHELLFISH_IRC_NETWORK='$irc_network'"
      else
        warn "Could not persist SHELLFISH_IRC_NETWORK; run: fish -c 'set -Ux SHELLFISH_IRC_NETWORK $irc_network'"
      fi
    fi
  else
    info "Dry run: would set SHELLFISH_IRC_NETWORK to '$irc_network'"
  fi

  if [[ "$dry_run" == "n" ]]; then
    copy_file "$SCRIPT_DIR/bash/.bashrc" "$SHELLFISH_BASHRC" 0644
    ensure_bashrc_snippet
  else
    info "Dry run: would update Shellfish Bash helpers and ensure ~/.bashrc sources them."
  fi

  if [[ "$dry_run" == "n" ]]; then
    mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
  fi
  local ssh_config="$HOME/.ssh/config"
  if [[ "$dry_run" == "n" ]]; then
    [[ -f "$ssh_config" ]] || { touch "$ssh_config"; chmod 600 "$ssh_config"; }
  fi

  local key_path="$HOME/.ssh/id_ed25519_github"
  local default_identity="$key_path"
  if [[ ! -f "$default_identity" ]]; then
    if [[ -f "$HOME/.ssh/id_ed25519" ]]; then default_identity="$HOME/.ssh/id_ed25519"
    elif [[ -f "$HOME/.ssh/id_rsa" ]]; then default_identity="$HOME/.ssh/id_rsa"
    fi
  fi

  if [[ "$use_github" == "y" ]]; then
    echo
    echo "GitHub username to preconfigure helpers (optional)."
    read -rp "GitHub username: " github_user
    if [[ -n "${github_user:-}" ]]; then
      if [[ "$dry_run" == "n" ]]; then
        command -v fish >/dev/null 2>&1 && {
          fish -c 'set -Ux GITGET_GITHUB_USER $argv[1]; set -Ux REPO_FUSE_GITHUB_USER $argv[1]' -- "$github_user" || true
        }
        if [[ -f "$HOME/.config/fish/repos/catalog.toml" ]]; then
          sed -i "s/your-github-username/$github_user/g" "$HOME/.config/fish/repos/catalog.toml" || true
        fi
      else
        info "Dry run: would set Fish universal GitHub vars to '$github_user'."
      fi
    else
      warn "Skipped setting GitHub username."
    fi

    if [[ -f "$SCRIPT_DIR/ssh/config" ]]; then
      echo
      echo "Install example ~/.ssh/config pointing GitHub to a dedicated key?"
      read -rp "Install example ssh config? [y/N] " install_ssh_config
      if [[ "$(normalize_answer "$install_ssh_config")" == "y" ]]; then
        if [[ "$dry_run" == "n" ]]; then
          copy_file "$SCRIPT_DIR/ssh/config" "$ssh_config" 0600
        else
          info "Dry run: would install sample ~/.ssh/config."
        fi
      else
        info "Skipped installing example ssh/config."
      fi
    fi

    if [[ ! -f "$key_path" ]]; then
      echo
      echo "Create GitHub-specific SSH key?"
      read -rp "Generate new SSH key at $key_path? [y/N] " generate_key
      if [[ "$(normalize_answer "$generate_key")" == "y" ]]; then
        read -rp "Email/comment to embed in the SSH key [$USER@github]: " key_comment
        key_comment="${key_comment:-$USER@github}"
        if [[ "$dry_run" == "n" ]]; then
          ssh-keygen -t ed25519 -f "$key_path" -C "$key_comment" -N ""
          info "Generated SSH key. Add the public key to GitHub."
        else
          info "Dry run: would generate $key_path with comment '$key_comment'."
        fi
      else
        warn "Skipping SSH key generation."
      fi
    else
      info "Existing $key_path key found."
    fi

    if [[ -f "$key_path" ]]; then
      if [[ "$dry_run" == "n" ]]; then
        start_ssh_agent_if_needed
        ssh-add "$key_path" || warn "Could not add SSH key to agent."
      else
        info "Dry run: would add $key_path to ssh-agent."
      fi
    fi
  else
    warn "Skipping GitHub configuration."
  fi

  echo
  echo "SSH shortcuts are friendly aliases that you can use to connect with single word to another computer - defined in ~/.ssh/config."
  read -rp "Create SSH shortcuts now? [Y/n] " add_hosts_answer
  if [[ "$(normalize_answer "$add_hosts_answer")" == "y" ]]; then
    local host_alias host_name host_user host_port host_identity
    local ssh_backup_done=0
    while true; do
      echo
      read -rp "Shortcut name (alias) (leave blank to finish): " host_alias
      [[ -z "$host_alias" ]] && break
      if [[ "$dry_run" == "n" ]]; then
        if grep -q "^[Hh]ost[[:space:]]\+$host_alias$" "$ssh_config" 2>/dev/null; then
          warn "Host '$host_alias' already exists in $ssh_config. Skipping."; continue
        fi
      fi
      read -rp "Hostname or IP (e.g., server.example.com): " host_name
      [[ -z "$host_name" ]] && { warn "Hostname cannot be empty."; continue; }
      read -rp "SSH username [$USER]: " host_user
      host_user="${host_user:-$USER}"
      read -rp "Port [22]: " host_port
      host_port="${host_port:-22}"
      read -rp "Identity file [$default_identity]: " host_identity
      host_identity="${host_identity:-$default_identity}"

      if [[ "$dry_run" == "n" ]]; then
        if [[ $ssh_backup_done -eq 0 && -f "$ssh_config" ]]; then
          local backup="${ssh_config}.${TIMESTAMP}.bak"
          cp -f "$ssh_config" "$backup"
          info "Backed up existing $ssh_config → $backup"
          record_managed_path "$ssh_config"
          ssh_backup_done=1
        elif [[ $ssh_backup_done -eq 0 ]]; then
          record_managed_path "$ssh_config"
          ssh_backup_done=1
        fi
        {
          echo ""
          echo "# Added by shellfish $(date '+%Y-%m-%d %H:%M:%S')"
          echo "Host $host_alias"
          echo "  HostName $host_name"
          echo "  User $host_user"
          echo "  Port $host_port"
          echo "  IdentityFile $host_identity"
          echo "  IdentitiesOnly yes"
        } >> "$ssh_config"
        info "Added host '$host_alias' to $ssh_config"
      else
        info "Dry run: would append host '$host_alias' to $ssh_config."
      fi
    done
  fi

  if [[ "$use_github" == "y" ]]; then
    if [[ "$dry_run" == "n" ]]; then
      if ! gh auth status >/dev/null 2>&1; then
        warn "GitHub CLI not logged in. Run: gh auth login --hostname github.com --git-protocol ssh --web"
      else
        info "GitHub CLI already authenticated."
      fi
    else
      info "Dry run: would check gh auth status."
    fi
  fi

  if command -v fish >/dev/null 2>&1; then
    local current_shell
    current_shell="$(basename "${SHELL:-}")"
    if [[ "$current_shell" != "fish" ]]; then
      if [[ "$dry_run" == "n" ]]; then
        info "Setting fish as the default shell (was $current_shell)."
        if ! grep -Fxq "$(command -v fish)" /etc/shells 2>/dev/null; then
          command -v fish | sudo tee -a /etc/shells >/dev/null || true
        fi
        chsh -s "$(command -v fish)" || warn "Could not change default shell automatically; run 'chsh -s $(command -v fish)' manually."
      else
        info "Dry run: would run chsh -s $(command -v fish)."
      fi
    fi
  else
    warn "fish executable not found; cannot change default shell."
  fi

  echo
  echo "Next steps:"
  if [[ "$use_github" == "y" ]]; then
    echo "  • If you generated a key: cat ~/.ssh/id_ed25519_github.pub → GitHub Settings → SSH and GPG keys."
    echo "  • Run: gh auth login --hostname github.com --git-protocol ssh --web"
  else
    echo "  • (Optional) Configure GitHub later: fish -c 'set -Ux REPO_FUSE_GITHUB_USER <username>'"
  fi
  echo "  • Review ~/.config/fish/repos/catalog.toml and replace sample entries with your projects."
  echo "  • Open a new Fish terminal and try:"
  echo "       gitget --list"
  echo "       gitget --pick"
  echo "       gf --list"
  echo "       repo_fuse --source github --list"
  echo "       screens / scr"
  echo "  • Optionally install extra tooling (bun, nodejs, build-essential, Docker, VS Code, …)."

  printf "\n%s\n" "$SHELLFISH_ASCII"
  info "Shellfish v${SHELLFISH_VERSION} complete."

  if [[ "$dry_run" == "n" ]]; then
    read -rp "Remove the installer directory $(pwd) now? [y/N] " cleanup
    if [[ "$(normalize_answer "$cleanup")" == "y" ]]; then
      local install_dir="$(pwd)"
      local parent_dir="$(dirname "$install_dir")"
      cd "$HOME"
      if rm -rf "$install_dir"; then
        info "Removed $install_dir"
        cd "$parent_dir" 2>/dev/null || true
      else
        warn "Could not remove $install_dir automatically; delete it manually if desired."
      fi
    fi
  fi
}

main "$@"
