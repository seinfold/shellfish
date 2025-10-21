set -l shellfish_user_paths \
    "$HOME/.local/bin" \
    "$HOME/.local/share/pnpm" \
    "$HOME/.npm-global/bin" \
    "$HOME/.yarn/bin" \
    "$HOME/.config/yarn/global/node_modules/.bin" \
    "$HOME/.poetry/bin" \
    "$HOME/.cargo/bin" \
    "$HOME/.bun/bin" \
    "$HOME/.dotnet/tools" \
    "$HOME/.pyenv/shims" \
    "$HOME/.config/composer/vendor/bin" \
    "$HOME/bin" \
    "$HOME/.local/share/flatpak/exports/bin"

set -l shellfish_system_paths \
    /usr/local/bin \
    /usr/local/sbin \
    /snap/bin \
    /var/lib/flatpak/exports/bin

for dir in $shellfish_user_paths $shellfish_system_paths
    if test -d "$dir"
        fish_add_path -g "$dir"
    end
end
