#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SHELLFISH_VERSION="1.0.0"

read -r -d '' SHELLFISH_ASCII <<'EOF'
      __
  ><((__o   shellfish
      )     terminal toolkit
     ((
EOF

STATE_DIR="$HOME/.local/share/shellfish"
MANIFEST_FILE="$STATE_DIR/managed_files.txt"
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
  "$HOME/.ssh/config"
)

info()  { printf "\033[1;34m[info]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[err ]\033[0m %s\n" "$*"; }

normalize_answer() {
    local ans="${1:-}"
    ans="${ans,,}"
    if [[ -z "$ans" || "$ans" == "y" || "$ans" == "yes" ]]; then
        printf "y"
    else
        printf "n"
    fi
}

contains_path() {
    local candidate="$1"
    local path
    for path in "${MANAGED_PATHS[@]}"; do
        if [[ "$path" == "$candidate" ]]; then
            return 0
        fi
    done
    return 1
}

add_known_path() {
    local candidate="$1"
    if contains_path "$candidate"; then
        return 0
    fi
    MANAGED_PATHS+=("$candidate")
}

record_managed_path() {
    local candidate="$1"
    add_known_path "$candidate"
    mkdir -p "$STATE_DIR"
    if [[ -f "$MANIFEST_FILE" ]]; then
        if ! grep -Fxq "$candidate" "$MANIFEST_FILE"; then
            echo "$candidate" >> "$MANIFEST_FILE"
        fi
    else
        echo "$candidate" > "$MANIFEST_FILE"
    fi
}

ensure_state() {
    MANAGED_PATHS=()
    mkdir -p "$STATE_DIR"
    if [[ -f "$MANIFEST_FILE" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && add_known_path "$line"
        done < "$MANIFEST_FILE"
    fi
    local path
    for path in "${DEFAULT_PATHS[@]}"; do
        add_known_path "$path"
    done
}

has_shellfish_backups() {
    local file
    for file in "${MANAGED_PATHS[@]}"; do
        if compgen -G "${file}".*.bak >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

restore_shellfish() {
    local file latest restored=0
    for file in "${MANAGED_PATHS[@]}"; do
        latest=$(ls -t "${file}".*.bak 2>/dev/null | head -n1 || true)
        if [[ -n "$latest" ]]; then
            mkdir -p "$(dirname "$file")"
            cp -f "$latest" "$file"
            info "Restored $file from $(basename "$latest")"
            restored=1
        else
            if [[ -e "$file" ]]; then
                if [[ -d "$file" ]]; then
                    rm -rf "$file"
                    info "Removed Shellfish-managed directory $file"
                else
                    rm -f "$file"
                    info "Removed Shellfish-managed file $file"
                fi
                restored=1
            fi
        fi
    done
    if (( restored )); then
        rm -f "$MANIFEST_FILE"
        info "Restoration complete. Backups (if any) remain on disk for manual reference."
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
        if ! curl -fsSL "$url" -o "$archive"; then
            warn "Downloading Nerd Font archive failed."; rm -rf "$tmp_dir"; return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q "$url" -O "$archive"; then
            warn "Downloading Nerd Font archive failed."; rm -rf "$tmp_dir"; return 1
        fi
    else
        warn "Neither curl nor wget available; cannot download Nerd Font."; rm -rf "$tmp_dir"; return 1
    fi

    mkdir -p "$fonts_dir"
    if ! unzip -o "$archive" -d "$fonts_dir" >/dev/null; then
        warn "Unzipping Nerd Font archive failed."; rm -rf "$tmp_dir"; return 1
    fi
    rm -rf "$tmp_dir"

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -fv "$fonts_root" >/dev/null || warn "fc-cache refresh failed; run 'fc-cache -fv ~/.local/share/fonts' manually."
    else
        warn "fc-cache not found; run 'fc-cache -fv ~/.local/share/fonts' to refresh fonts."
    fi

    info "JetBrainsMono Nerd Font installed under $fonts_dir. Set it in your terminal preferences."
    record_managed_path "$fonts_dir"
    return 0
}

copy_file() {
    local src="$1"
    local dest="$2"
    local mode="${3:-644}"

    if [[ ! -f "$src" ]]; then
        error "Missing source file: $src"
        exit 1
    fi

    local dest_dir
    dest_dir="$(dirname "$dest")"
    mkdir -p "$dest_dir"

    if [[ -e "$dest" && ! -L "$dest" ]]; then
        local backup="${dest}.${TIMESTAMP}.bak"
        cp -f "$dest" "$backup"
        info "Backed up existing $(realpath -m "$dest") → $backup"
    fi

    install -m "$mode" "$src" "$dest"
    info "Installed $(basename "$src") → $dest"
    record_managed_path "$dest"
}

ensure_package() {
    local pkg="$1"
    local manager="$2"
    case "$manager" in
        apt)
            if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                sudo apt-get install -y "$pkg"
            fi
            ;;
        *)
            warn "Package manager '$manager' not supported for auto-install."
            ;;
    esac
}

ensure_packages() {
    local packages=("$@")
    if command -v apt-get >/dev/null 2>&1; then
        info "Updating package index…"
        sudo apt-get update
        local pkg
        for pkg in "${packages[@]}"; do
            info "Installing $pkg…"
            ensure_package "$pkg" apt || warn "Could not install $pkg automatically. Install manually."
        done
    else
        warn "Unsupported package manager. Install the following manually: ${packages[*]}"
    fi
}

main() {
    local dry_run="n"
    if [[ "${1:-}" == "--dry-run" ]]; then
        dry_run="y"
        info "Dry run mode. No changes will be made, but prompts will appear."
    fi

    printf "\n%s\n\n" "$SHELLFISH_ASCII"
    info "Shellfish v${SHELLFISH_VERSION} — prepping your Fish terminal environment."

    ensure_state

    local previous_state="n"
    if has_shellfish_backups || [[ -f "$MANIFEST_FILE" ]]; then
        previous_state="y"
    fi

    if [[ "$previous_state" == "y" ]]; then
        echo
        echo "It looks like Shellfish has modified this system before (backups/state detected)."
        if has_shellfish_backups; then
            read -rp "Revert Shellfish changes using available backups? [y/N] " revert_ans
            if [[ "$(normalize_answer "$revert_ans")" == "y" ]]; then
                if [[ "$dry_run" == "n" ]]; then
                    if restore_shellfish; then
                        ensure_state
                        info "Shellfish settings reverted to the previous state."
                    fi
                else
                    info "Dry run: would restore previous Shellfish backups here."
                fi
                read -rp "Run Shellfish setup again with fresh settings? [Y/n] " rerun_after_restore
                if [[ "$(normalize_answer "$rerun_after_restore")" != "y" ]]; then
                    info "Exiting without further changes."
                    printf "\n%s\n" "$SHELLFISH_ASCII"
                    return 0
                fi
            else
                read -rp "Proceed with Shellfish installation without reverting? [Y/n] " proceed_ans
                if [[ "$(normalize_answer "$proceed_ans")" != "y" ]]; then
                    info "Exiting without changes."
                    printf "\n%s\n" "$SHELLFISH_ASCII"
                    return 0
                fi
            fi
        else
            read -rp "Shellfish state found. Run setup again with new settings? [Y/n] " rerun_only
            if [[ "$(normalize_answer "$rerun_only")" != "y" ]]; then
                info "Exiting without changes."
                printf "\n%s\n" "$SHELLFISH_ASCII"
                return 0
            fi
        fi
    fi

    echo
    read -rp "Do you use GitHub for development? [Y/n] " answer
    local use_github
    use_github="$(normalize_answer "$answer")"

    echo
    echo "Shellfish ships an IRC toolkit (GNU screen + irssi) for the scr/screens helpers."
    read -rp "Install IRC tooling (screen + irssi)? [Y/n] " answer
    local install_irc
    install_irc="$(normalize_answer "$answer")"

    echo
    echo "Shellfish can install JetBrainsMono Nerd Font (Light variants) locally for crisp icons."
    echo "Fonts are copied to ~/.local/share/fonts and available system-wide for your user."
    read -rp "Install JetBrainsMono Nerd Font Light? [Y/n] " answer
    local install_font
    install_font="$(normalize_answer "$answer")"

    local packages=(
        fish git curl wget python3 python3-pip python3-venv
        eza tree zoxide fzf neofetch unzip
    )
    if [[ "$use_github" == "y" ]]; then
        packages+=(gh)
    fi
    if [[ "$install_irc" == "y" ]]; then
        packages+=(screen irssi)
    else
        warn "Skipping screen/irssi; note that the scr/screens helpers require GNU screen."
    fi

    if [[ "$dry_run" == "n" ]]; then
        ensure_packages "${packages[@]}"
    else
        info "Dry run: would install packages: ${packages[*]}"
    fi

    if [[ "$install_font" == "y" ]]; then
        if [[ "$dry_run" == "n" ]]; then
            if ! install_nerd_font; then
                warn "JetBrainsMono Nerd Font installation encountered issues."
            fi
        else
            info "Dry run: would install JetBrainsMono Nerd Font Light to ~/.local/share/fonts."
        fi
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

    if [[ -f "$SCRIPT_DIR/bash/.bashrc" ]]; then
        echo
        echo "Shellfish can replace ~/.bashrc with its tuned prompt."
        echo "A timestamped backup (.bashrc.${TIMESTAMP}.bak) will be created before overwriting."
        read -rp "Replace ~/.bashrc with the Shellfish version? [y/N] " replace_bash
        if [[ "$(normalize_answer "$replace_bash")" == "y" ]]; then
            if [[ "$dry_run" == "n" ]]; then
                copy_file "$SCRIPT_DIR/bash/.bashrc" "$HOME/.bashrc" 644
            else
                info "Dry run: would update ~/.bashrc and create a backup."
            fi
        else
            info "Skipped .bashrc update."
        fi
    fi

    if [[ "$dry_run" == "n" ]]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
    fi
    local ssh_config="$HOME/.ssh/config"
    if [[ "$dry_run" == "n" ]]; then
        if [[ ! -f "$ssh_config" ]]; then
            touch "$ssh_config"
            chmod 600 "$ssh_config"
        fi
    fi

    local key_path="$HOME/.ssh/id_ed25519_github"
    local default_identity="$key_path"
    if [[ ! -f "$default_identity" ]]; then
        if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
            default_identity="$HOME/.ssh/id_ed25519"
        elif [[ -f "$HOME/.ssh/id_rsa" ]]; then
            default_identity="$HOME/.ssh/id_rsa"
        fi
    fi

    if [[ "$use_github" == "y" ]]; then
        echo
        echo "GitHub username lets gitget and repo_fuse list your repositories automatically."
        echo "Press Enter to skip; you can set it later with:"
        echo "  fish -c 'set -Ux REPO_FUSE_GITHUB_USER <username>'"
        read -rp "GitHub username: " github_user
        if [[ -n "$github_user" ]]; then
            if [[ "$dry_run" == "n" ]]; then
                if command -v fish >/dev/null 2>&1; then
                    fish -c "set -Ux REPO_FUSE_GITHUB_USER $github_user" || true
                    fish -c "set -Ux GITGET_GITHUB_USER $github_user" || true
                fi
                if [[ -f "$HOME/.config/fish/repos/catalog.toml" ]]; then
                    if grep -q "your-github-username" "$HOME/.config/fish/repos/catalog.toml"; then
                        sed -i "s/your-github-username/$github_user/g" "$HOME/.config/fish/repos/catalog.toml"
                    fi
                fi
            else
                info "Dry run: would set Fish universal GitHub variables to '$github_user'."
            fi
        else
            warn "Skipped setting GitHub username. You can configure it later."
        fi

        if [[ -f "$SCRIPT_DIR/ssh/config" ]]; then
            echo
            echo "Shellfish can install a sample ~/.ssh/config that points GitHub to this SSH key."
            echo "Any existing file is backed up automatically."
            read -rp "Install the example ssh config? [y/N] " install_ssh_config
            if [[ "$(normalize_answer "$install_ssh_config")" == "y" ]]; then
                if [[ "$dry_run" == "n" ]]; then
                    copy_file "$SCRIPT_DIR/ssh/config" "$ssh_config" 600
                else
                    info "Dry run: would install sample ~/.ssh/config (with backup)."
                fi
            else
                info "Skipped installing example ssh/config."
            fi
        fi

        if [[ ! -f "$key_path" ]]; then
            echo
            echo "You need an SSH key registered with GitHub to clone over SSH."
            echo "Shellfish can generate a GitHub-specific key now (ed25519)."
            read -rp "Generate new SSH key at $key_path? [y/N] " generate_key
            if [[ "$(normalize_answer "$generate_key")" == "y" ]]; then
                read -rp "Email/comment to embed in the SSH key [$USER@github]: " key_comment
                key_comment="${key_comment:-$USER@github}"
                if [[ "$dry_run" == "n" ]]; then
                    ssh-keygen -t ed25519 -f "$key_path" -C "$key_comment" -N ""
                    info "Generated SSH key. Remember to add the public key to GitHub."
                else
                    info "Dry run: would generate $key_path with comment '$key_comment'."
                fi
            else
                warn "Skipping SSH key generation. Ensure $key_path exists before cloning."
            fi
        else
            info "Existing $key_path key found."
        fi

        if [[ -f "$key_path" && "$dry_run" == "n" ]]; then
            ssh-add "$key_path" || warn "Could not add SSH key to agent."
        elif [[ -f "$key_path" ]]; then
            info "Dry run: would add $key_path to ssh-agent."
        fi
    else
        warn "Skipping GitHub configuration. gitget/repo_fuse will work offline; set usernames later if needed."
    fi

    echo
    echo "SSH shortcuts are friendly aliases (e.g., 'ssh prod') defined in ~/.ssh/config."
    read -rp "Create SSH shortcuts now? [Y/n] " add_hosts_answer
    if [[ "$(normalize_answer "$add_hosts_answer")" == "y" ]]; then
        local host_alias host_name host_user host_port host_identity
        local ssh_backup_done=0
        while true; do
            echo
            read -rp "Shortcut name (alias) (leave blank to finish): " host_alias
            if [[ -z "$host_alias" ]]; then
                break
            fi
            if [[ "$dry_run" == "n" ]]; then
                if grep -q "^[Hh]ost[[:space:]]\+$host_alias$" "$ssh_config" 2>/dev/null; then
                    warn "Host '$host_alias' already exists in $ssh_config. Skipping."
                    continue
                fi
            fi
            read -rp "Hostname or IP (e.g., server.example.com): " host_name
            if [[ -z "$host_name" ]]; then
                warn "Hostname cannot be empty."
                continue
            fi
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
            info "Dry run: would check gh auth status here."
        fi
    fi

    if [[ "${CHSH_DONE:-0}" -eq 0 ]]; then
        if command -v fish >/dev/null 2>&1; then
            local current_shell
            current_shell="$(basename "${SHELL:-}")"
            if [[ "$current_shell" != "fish" ]]; then
                read -rp "Set fish as your default shell? [y/N] " set_default
                if [[ "$(normalize_answer "$set_default")" == "y" ]]; then
                    if [[ "$dry_run" == "n" ]]; then
                        chsh -s "$(command -v fish)"
                        info "Default shell changed to fish. Log out and back in to apply."
                    else
                        info "Dry run: would run chsh to set fish as default shell."
                    fi
                fi
            fi
        fi
        export CHSH_DONE=1
    fi

    echo
    echo "Next steps:"
    if [[ "$use_github" == "y" ]]; then
        echo "  • If you generated a key: cat ~/.ssh/id_ed25519_github.pub → GitHub Settings → SSH and GPG keys."
        echo "  • Run: gh auth login --hostname github.com --git-protocol ssh --web"
    else
        echo "  • (Optional) Configure GitHub later with: fish -c 'set -Ux REPO_FUSE_GITHUB_USER <username>'"
        echo "    and add an SSH key when you switch to GitHub over SSH."
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
    info "Shellfish v${SHELLFISH_VERSION} complete. Happy hacking!"
}

main "$@"
