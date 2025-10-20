function gameserver --description 'Placeholder helper for your preferred SSH shortcut'
    echo "Customize gameserver.fish with your own SSH command (e.g., ssh user@host)."
end

function GAMESERVER --description ' SSH into the game server '
    gameserver $argv
end
