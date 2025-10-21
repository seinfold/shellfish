# ----- aliases -----
alias ls "eza --icons"
alias treelist "tree -a -I '.git'"

# ----- ssh shortcuts -----
set -l __shellfish_ssh_shortcuts "$HOME/.config/fish/functions/ssh_shortcuts.fish"
if test -f $__shellfish_ssh_shortcuts
    source $__shellfish_ssh_shortcuts
end

# ----- IRC helper (GNU screen + irssi) -----
function irc
    if not type -q screen
        echo "Shellfish: GNU screen is missing. Install it." >&2
        return 1
    end
    if not type -q irssi
        echo "Shellfish: irssi is missing. Install it, then run: screen -S irc irssi" >&2
        return 1
    end

    set -l target_network (set -q SHELLFISH_IRC_NETWORK; and echo $SHELLFISH_IRC_NETWORK; or echo ircnet)

    if set -q STY
        if screen -S "$STY" -Q windows | string match -q "*irc*"
            screen -S "$STY" -X select irc
        else
            screen -S "$STY" -X screen -t irc irssi -c "$target_network"
            screen -S "$STY" -X select irc
        end
        return
    end

    if string match -q -r '\.irc(\s|$)' -- (screen -ls 2>/dev/null)
        screen -S irc -D -RR
    else
        screen -S irc -D -RR irssi -c "$target_network"
    end
end

# ----- keep apps alive after closing terminal -----
# usage: stay <command>
function stay
    nohup $argv > /dev/null 2>&1 < /dev/null & disown
end

# ----- timing & IPs for greeting -----
set -l NOW (date "+%Y-%m-%d %H:%M:%S")

set -l LOCAL_IP "unknown"
if type -q ip
    set -l ip_candidates (ip -4 addr show scope global 2>/dev/null | string match -rg 'inet ([0-9\.]+)')
    if test (count $ip_candidates) -gt 0
        set LOCAL_IP $ip_candidates[1]
    end
end

if test "$LOCAL_IP" = "unknown"
    if type -q hostname
        set -l host_candidates (command hostname -I 2>/dev/null)
        if test (count $host_candidates) -gt 0
            set LOCAL_IP $host_candidates[1]
        end
    end
end

if test "$LOCAL_IP" = "unknown"
    if type -q ifconfig
        set -l ifconfig_candidates (ifconfig 2>/dev/null | string match -rg 'inet ([0-9\.]+)')
        set ifconfig_candidates (string match -v '127.0.0.1' $ifconfig_candidates)
        if test (count $ifconfig_candidates) -gt 0
            set LOCAL_IP $ifconfig_candidates[1]
        end
    end
end

set -l EXTERNAL_IP "offline"
if type -q curl
    set -l ext (curl -s --max-time 2 https://ifconfig.me 2>/dev/null)
    if test -n "$ext"
        set EXTERNAL_IP $ext
    end
end

set fish_greeting (string join ' ' \
    (set_color --bold 06b6d4)"[$NOW]" \
    (set_color --bold 14b8a6)"L:$LOCAL_IP" \
    (set_color --bold efcf40)"E:$EXTERNAL_IP" \
    (set_color normal))

# ----- random shellfish greeting -----
function __shellfish_greeting_phrase --description 'Randomized greeting line'
    set -l user $USER
    set -l host (prompt_hostname)
    set -l cwd  (prompt_pwd)

    set -l verbs  guarding watching assimilating polishing sysjacking hoarding compiling bending herding tailing 
    set -l nouns  loot cargo repos dotfiles processes constructs agents anomalies the-matrix codes shells screens payloads protocols netghosts nanoclusters feeds packets systems sockets branches merges builds daemons kernels collection neuralnets 

    set -l templates \
        "shellfish is now {verb} your {noun}" \
        "ahoy {user}@{host} — {verb} your {noun}" \
        "{user}, {verb} your {noun} in {cwd}" \
        "crew ready on {host}; {verb} your {noun}" \
        "{verb} your {noun}, {user}"

    set -l v (random 1 (count $verbs))
    set -l n (random 1 (count $nouns))
    set -l t (random 1 (count $templates))

    set -l phrase $templates[$t]
    set phrase (string replace -a '{user}' $user -- $phrase)
    set phrase (string replace -a '{host}' $host -- $phrase)
    set phrase (string replace -a '{cwd}'  $cwd  -- $phrase)
    set phrase (string replace -a '{verb}' $verbs[$v] -- $phrase)
    set phrase (string replace -a '{noun}' $nouns[$n] -- $phrase)
    echo $phrase
end

# ----- greeting -----
if status is-interactive
    set_color --bold 06b6d4
    printf '\n      __\n  ><((__o  '
    set_color --bold 14b8a6
    echo (__shellfish_greeting_phrase)
    set_color normal
    echo
end

# ----- key bindings -----
function fish_user_key_bindings
    fish_vi_key_bindings
    # Map 'kj' to escape from insert mode
    bind -M insert kj 'set fish_bind_mode default; commandline -f repaint'
end

# ----- vi mode indicator (left of prompt) -----
function fish_mode_prompt
    switch "$fish_bind_mode"
        case default
            echo -n (set_color --bold f43f5e)"N"
        case insert
            echo -n (set_color --bold 84cc16)"I"
        case visual
            echo -n (set_color --bold 8b5cf6)"V"
        case '*'
            echo -n (set_color --bold)"?"
    end
    echo -n " "
end

# Always use block caret in normal mode (set once, universal)
set -q fish_cursor_default; or set -U fish_cursor_default block

# ----- prompt -----
function fish_prompt
    set_color --bold 4086ef
    set transformed_pwd (prompt_pwd | string replace -r "^~" (set_color --bold 06b6d4)"~"(set_color --bold 3b82f6))
    echo -n $transformed_pwd
    echo -n " "
    echo -n (set_color --bold 14b8a6)"→"
    echo -n " "
    set_color normal
end

# ----- PATHs -----
fish_add_path /usr/local/bin /opt/bin
fish_add_path $HOME/.cargo/bin

# bun
set -gx BUN_INSTALL "$HOME/.bun"
fish_add_path $BUN_INSTALL/bin

# pnpm
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
fish_add_path $PNPM_HOME

# zoxide (Linux)
if type -q zoxide
    zoxide init fish | source
end

# Homebrew on Linux (optional)
if test -x /home/linuxbrew/.linuxbrew/bin/brew
    eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
end

# ----- env -----
set -gx EDITOR vim
# Force XCB only under X11; Wayland users usually don’t need this.
if test "$XDG_SESSION_TYPE" = "x11"
    set -gx QT_QPA_PLATFORM xcb
end

# ----- colors (TokyoNight-ish) -----
set -l foreground c0caf5
set -l selection 6366f1
set -l comment 737373
set -l red f7768e
set -l orange ff9e64
set -l yellow e0af68
set -l green 9ece6a
set -l purple 9d7cd8
set -l cyan 7dcfff
set -l pink bb9af7

# Syntax Highlighting Colors
set -g fish_color_normal $foreground
set -g fish_color_command $cyan
set -g fish_color_keyword $pink
set -g fish_color_quote $yellow
set -g fish_color_redirection $foreground
set -g fish_color_end $orange
set -g fish_color_error $red
set -g fish_color_param $purple
set -g fish_color_comment $comment
set -g fish_color_selection --background=$selection
set -g fish_color_search_match --background=$selection
set -g fish_color_operator $green
set -g fish_color_escape $pink
set -g fish_color_autosuggestion $comment

# Completion Pager Colors
set -g fish_pager_color_progress $comment
set -g fish_pager_color_prefix $cyan
set -g fish_pager_color_completion $foreground
set -g fish_pager_color_description $comment
set -g fish_pager_color_selected_background --background=$selection
