function scr --description 'create/attach a GNU screen session by name, with optional logging'
    test (count $argv) -lt 1; and begin
        echo "scr NAME [log]"; return 2
    end

    set -l name $argv[1]
    set -l want_log 0
    if test (count $argv) -ge 2; and test "$argv[2]" = "log"
        set want_log 1
    end

    if screen -ls ^/dev/null | awk '/\t/ {split($1,a,"."); print a[2]}' | grep -x -- $name >/dev/null
        exec screen -x -r $name
    end

    if test $want_log -eq 1
        set -l dir ~/Documents/logs
        mkdir -p $dir
        set -l ts (date "+%Y%m%d-%H%M%S")
        set -l file "$dir/$name-$ts.log"
        exec screen -S $name -L -Logfile $file
    else
        exec screen -S $name
    end
end
