# ~/.config/fish/functions/scr.fish
# Create or attach a GNU screen session by NAME.
# SSH-aware: never tries to open a GUI terminal over SSH / headless.
# Flags:
#   -l, --log              enable logging (~/Documents/logs)
#   -t, --title TITLE      window title (defaults to NAME)
#   -h, --help             show help
status is-interactive; or return

function scr --description 'create/attach a screen session'
    command -q screen; or begin
        echo "screen missing"; return 127
    end

    # ---------- parse args (simple & robust) ----------
    if test (count $argv) -eq 0
        echo "usage: scr NAME [-l] [-t TITLE]"
        return 2
    end

    set -l name ""
    set -l want_log 0
    set -l title ""

    for i in (seq (count $argv))
        switch $argv[$i]
            case -h --help
                echo "usage: scr NAME [-l] [-t TITLE]"
                return 0
            case -l --log
                set want_log 1
            case -t --title
                set i (math $i + 1); set title $argv[$i]
            case '*'
                if test -z "$name"; set name $argv[$i]; end
        end
    end

    if test -z "$name"
        echo "error: missing NAME"
        return 2
    end

    # ---------- build screen command ----------
    set -l cmd "screen -S '$name' -D -RR"

    if test $want_log -eq 1
        set -l dir "$HOME/Documents/logs"
        mkdir -p $dir
        set -l ts (date "+%Y%m%d-%H%M%S")
        set -l file "$dir/$name-$ts.log"
        set cmd "$cmd -L -Logfile '$file'"
        ln -sf "$file" "$dir/$name-latest.log"
    end

    if test -z "$title"; set title "$name"; end

    # ---------- decide whether to use a GUI terminal ----------
    # Some setups leak DISPLAY=:0 into SSH. Treat any SSH as headless.
    set -l has_gui 1
    if set -q SSH_CONNECTION
        set has_gui 0
    end
    if not set -q DISPLAY; and not set -q WAYLAND_DISPLAY
        set has_gui 0
    end

    # Update terminal title in any case
    printf '\033]0;%s\007' "$title"

    if test $has_gui -eq 1
        set -l bashcmd (string escape -- "$cmd")

        if type -q kitty
            command kitty --title "$title" bash -lc $bashcmd
        else if type -q wezterm
            command wezterm start --title "$title" -- bash -lc $bashcmd
        else if type -q gnome-terminal
            command gnome-terminal --title="$title" -- bash -lc $bashcmd
        else if type -q xfce4-terminal
            command xfce4-terminal --title="$title" -x bash -lc $bashcmd
        else if type -q tilix
            command tilix --title "$title" -e bash -lc $bashcmd
        else if type -q konsole
            command konsole -p tabtitle="$title" -e bash -lc $bashcmd &
        else if type -q xterm
            command xterm -T "$title" -e bash -lc $bashcmd
        else
            # No GUI emulators found; run in current TTY
            eval $cmd
        end
    else
        # Headless/SSH: run in current terminal
        eval $cmd
    end
end

# tab-completion
complete -c scr -s l -l log -d 'log to ~/Documents/logs'
complete -c scr -s t -l title -r -d 'window title'
