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
    
    # Check if we're in an SSH session
    if set -q SSH_CONNECTION; or set -q SSH_CLIENT; or set -q SSH_TTY
        # We're in SSH - attach directly in current terminal
        if test $want_log -eq 1
            set -l dir "$HOME/Documents/logs"
            mkdir -p $dir
            set -l ts (date "+%Y%m%d-%H%M%S")
            set -l file "$dir/$name-$ts.log"
            command screen -S $name -D -RR -L -Logfile $file
        else
            command screen -S $name -D -RR
        end
        return
    end
    
    # Not in SSH - use GUI terminal (original behavior)
    set -l cmd "screen -S '$name' -D -RR"
    if test $want_log -eq 1
        set -l dir "$HOME/Documents/logs"
        mkdir -p $dir
        set -l ts (date "+%Y%m%d-%H%M%S")
        set -l file "$dir/$name-$ts.log"
        set cmd "screen -S '$name' -D -RR -L -Logfile '$file'"
    end
    if type -q gnome-terminal
        command gnome-terminal --title="$name" -- bash -lc "$cmd"
    else if type -q xterm
        command xterm -T "$name" -e $cmd
    else
        printf '\033]0;%s\007' "$name"
        command screen -S $name -D -RR
    end
end
