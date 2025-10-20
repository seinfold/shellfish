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

    set -l existing
    for line in (screen -ls 2>/dev/null)
        if string match -qr '^[0-9]+\.[^ ]+' -- $line
            set parts (string split '.' $line)
            if test (count $parts) -ge 2
                set -a existing $parts[2]
            end
        end
    end

    if contains -- $name $existing
        command screen -x -r $name
        return $status
    end

    if test $want_log -eq 1
        set -l dir ~/Documents/logs
        mkdir -p $dir
        set -l ts (date "+%Y%m%d-%H%M%S")
        set -l file "$dir/$name-$ts.log"
        command screen -S $name -L -Logfile $file
    else
        command screen -S $name
    end
end
