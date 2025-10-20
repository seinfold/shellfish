function screens --description 'list screen session names, plus quick help'
    screen -ls ^/dev/null | awk '/\t/ {split($1,a,"."); print a[2]}'
    echo
    echo "Use:"
    echo "  scr NAME         # create/attach NAME"
    echo "  scr NAME log     # create/attach NAME with logging to ~/Documents/logs"
end
