function screens --description 'list screen session names, plus quick help'
    set -l sessions
    for line in (screen -ls 2>/dev/null)
        if string match -qr '^[0-9]+\.[^ ]+' -- $line
            set parts (string split '.' $line)
            if test (count $parts) -ge 2
                set -a sessions $parts[2]
            end
        end
    end

    if test (count $sessions) -eq 0
        echo "(no screen sessions)"
    else
        for session in $sessions
            echo $session
        end
    end

    echo
    echo "Use:"
    echo "  scr NAME         # create/attach NAME"
    echo "  scr NAME log     # create/attach NAME with logging to ~/Documents/logs"
end
