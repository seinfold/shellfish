if not status is-interactive
    return
end

if type -q repo_fuse
    abbr -a rf repo_fuse
    abbr -a gf repo_fuse
end

if type -q gitget
    abbr -a gg gitget
end
