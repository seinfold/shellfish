function screens --description 'List, attach, or delete GNU screen sessions'
    # Build a tab-delimited list: <name>\t<state>
    set -l rows (screen -ls 2>/dev/null | awk '
        /^[[:space:]]*[0-9]+\./ {
            n=split($1,a,"."); sess=(n>1?a[2]:$1);
            state=$2; gsub(/[()]/,"",state);
            printf "%s\t%s\n", sess, state
        }')

    if test -z "$rows"
        echo "No screen sessions."
        return
    end

    # Pretty print if no fzf
    if not type -q fzf
        printf '%s\n' $rows | awk -F'\t' '{printf "%-20s  %s\n",$1,$2}'
        return
    end

    set -l header 'Enter: attach   Ctrl-D: delete   ESC: go back'
    set -l choice (printf '%s\n' $rows | \
        fzf --prompt='screen> ' \
            --header="$header" \
            --delimiter='\t' --with-nth=1,2 \
            --bind='ctrl-d:execute-silent(screen -S {1} -X quit)+abort' \
            --select-1 --exit-0)

    if test -n "$choice"
        set -l sess (string split \t -- $choice)[1]
        scr $sess
    end
end
