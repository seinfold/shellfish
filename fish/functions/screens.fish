function screens --description 'list screen session names, plus quick help'
    screen -ls 2>/dev/null | awk '
        /^[[:space:]]*[0-9]+\./ {
            n = split($1,a,".")
            if (n>1) print a[2]
        }'
    echo
    echo "Use:"
    echo "  scr NAME         # create/attach NAME"
    echo "  scr NAME log     # create/attach NAME with logging to ~/Documents/logs"
end
