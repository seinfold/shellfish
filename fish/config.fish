# aliases

alias ls "eza --icons"
alias treelist "tree -a -I '.git'"

function irc
  set -l sessions (screen -ls ^/dev/null; or true)
  set -l has_session no
  if string match -q '*\.irc*' $sessions
    set has_session yes
  end

  if test "$has_session" = yes
    screen -x irc
  else
    screen -S irc irssi -c ircnet
  end
end

# prevents apps from closing when closing terminal
# usage: stay <command>
function stay
  nohup $argv > /dev/null 2>&1 < /dev/null & disown
end

# custom greeting
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

if status is-interactive
  printf '\n      __\n  ><((__o   shellfish\n      )     terminal toolkit\n     ((\n\n'
end

function fish_user_key_bindings
  fish_vi_key_bindings

  # set kj to <Esc>
  bind -M insert -m default kj backward-char force-repaint
end

# UNCOMMENT FOR RIGHT PROMPT 
# function fish_right_prompt
#   echo (set_color 71717a)"$USER"@(prompt_hostname)
# end

# indicator for vi
function fish_mode_prompt
  switch "$fish_bind_mode"
    case "default"
      echo -n (set_color --bold f43f5e)"N"
    case "insert"
      echo -n (set_color --bold 84cc16)"I"
    case "visual"
      echo -n (set_color --bold 8b5cf6)"V"
    case "*"
      echo -n (set_color --bold)"?"
  end

  echo -n " "
end

# always use block caret (vimode)
set -U fish_cursor_default block

# custom prompt
function fish_prompt
  set_color --bold 4086ef

  set transformed_pwd (prompt_pwd | string replace -r "^~" (set_color --bold 06b6d4)"~"(set_color --bold 3b82f6))

  echo -n $transformed_pwd

  # space between path and prompt arrow
  echo -n " "

  # arrows
  # echo -n (set_color --bold efcf40)"❱"
  # echo -n (set_color --bold ef9540)"❱"
  # echo -n (set_color --bold ea3838)"❱"
  
  echo -n (set_color --bold 14b8a6)"→"
  
  #space
  echo -n " "

  set_color normal
end

# set environment variables
fish_add_path /usr/local/bin
fish_add_path /opt/bin

# set editor
set -x EDITOR "vim"

set QT_QPA_PLATFORM xcb

# fzf
# export FZF_DEFAULT_OPTS="
# --bind='ctrl-j:down,ctrl-k:up,ctrl-t:toggle-all,ctrl-v:toggle-preview,ctrl-space:toggle-preview'
# --color=fg:#ffffff,hl:#00ff00,fg+:#a5b4fc,bg+:#737373,hl+:#ffff00,info:#14b8a6,spinner:#00ffff,pointer:#f59e0b
# "

# TokyoNight Color Palette from https://github.com/folke/tokyonight.nvim/blob/main/extras/fish/tokyonight_storm.fish
set -l foreground c0caf5
# changed from default
set -l selection 6366f1
# changed from default
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

# cargo
fish_add_path $HOME/.cargo/bin

# bun
set --export BUN_INSTALL "$HOME/.bun"
fish_add_path $BUN_INSTALL/bin

# pnpm
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
fish_add_path $PNPM_HOME

# fnm setup (homebrew or default)
if test (uname) = "Darwin"
  # macOS paths
  if test -x /opt/homebrew/bin/fnm
    fish_add_path /opt/homebrew/bin
    eval (/opt/homebrew/bin/fnm env)
  else if test -x $HOME/.fnm/fnm
    fish_add_path $HOME/.fnm
    eval (fnm env)
  end

  # zoxide setup (homebrew)
  if test -x /opt/homebrew/bin/zoxide
    fish_add_path /opt/homebrew/bin
    zoxide init fish | source
  end

  # homebrew shell environment (macOS only)
  if test -x /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
  end

  # LM Studio CLI (macOS)
  set -gx PATH $PATH $HOME/.lmstudio/bin
else
  # linux or other platforms
  if type -q zoxide
    zoxide init fish | source
  end

  if test -x /home/linuxbrew/.linuxbrew/bin/brew
    eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
  end
end
