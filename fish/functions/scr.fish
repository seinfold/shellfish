function scr --description 'create/attach a GNU screen session by name, with optional logging'
    if test (count $argv) -lt 1
        echo "scr NAME [log]"
        return 2
    end

    set -l name $argv[1]
    set -l want_log 0
    if test (count $argv) -ge 2
        if test "$argv[2]" = "log"
            set want_log 1
        end
    end

    set -l cmd "screen -S '$name' -D -RR"
    if test $want_log -eq 1
        set -l dir "$HOME/Documents/logs"
        mkdir -p $dir
        set -l ts (date "+%Y%m%d-%H%M%S")
        set -l file "$dir/$name-$ts.log"
        set cmd "screen -S '$name' -D -RR -L -Logfile '$file'"
    end

    if type -q gnome-terminal
        # Title the window with the screen session name
        command gnome-terminal --title="$name" -- bash -lc "$cmd"
    else if type -q xterm
        # -T sets the xterm title
        command xterm -T "$name" -e $cmd
    else
        # Fallback: set current terminal title, then run screen here
        printf '\033]0;%s\007' "$name"
        command screen -S $name -D -RR
    end
end
