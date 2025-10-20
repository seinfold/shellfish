function gitget -d "List or clone your GitHub repos quickly"
    if not type -q gh
        echo "gitget: GitHub CLI (gh) is required; install it first." >&2
        return 1
    end

    if not type -q git
        echo "gitget: git is required but was not found" >&2
        return 1
    end

    if not type -q python3
        echo "gitget: python3 is required but was not found" >&2
        return 1
    end

    set -l user
    if set -q GITGET_GITHUB_USER
        set user $GITGET_GITHUB_USER
    else if set -q REPO_FUSE_GITHUB_USER
        set user $REPO_FUSE_GITHUB_USER
    else
        set user (gh api user --jq .login 2>/dev/null)
        if test -z "$user"
            echo "gitget: unable to determine GitHub username (set GITGET_GITHUB_USER)" >&2
            return 1
        end
    end

    set -l raw (python3 -c '
import json
import subprocess
import sys

user = sys.argv[1]
cmd = [
    "gh", "repo", "list", user,
    "--limit", "1000",
    "--json", "name,sshUrl,isPrivate,owner",
]
proc = subprocess.run(cmd, capture_output=True, text=True)
if proc.returncode != 0:
    sys.stderr.write(proc.stderr or "gitget: gh repo list failed\n")
    sys.exit(proc.returncode or 1)

try:
    repos = json.loads(proc.stdout or "[]")
except json.JSONDecodeError:
    sys.stderr.write("gitget: failed to parse gh repo list output\n")
    sys.exit(1)

me = user.lower()
for repo in repos:
    name = repo.get("name") or ""
    ssh = repo.get("sshUrl") or ""
    owner = (repo.get("owner") or {}).get("login", "").lower()
    private = "1" if repo.get("isPrivate") else "0"
    if not name or not ssh:
        continue
    if owner and owner != me:
        continue
    print(f"{name}\t{ssh}\t{private}")
' "$user")
    if test $status -ne 0
        return 1
    end

    if test (count $raw) -eq 0 -o \( (count $raw) -eq 1 -a -z "$raw[1]" \)
        echo "gitget: no repositories found for $user" >&2
        return 1
    end

    set -l names
    set -l urls
    set -l priv_flags
    for line in $raw
        set -l fields (string split -- \t $line)
        set -a names $fields[1]
        set -a urls $fields[2]
        set -a priv_flags $fields[3]
    end
    set -l repo_count (count $names)

    set -l labels
    for idx in (seq $repo_count)
        set -l label $names[$idx].git
        if test "$priv_flags[$idx]" = 1
            set label "$label (private)"
        end
        set -a labels $label
    end

    function __gitget_print --description 'internal helper' -V labels
        for label in $labels
            echo $label
        end
    end

    function __gitget_clone -a idx target --description 'internal clone helper' -V names -V urls
        set -l name $names[$idx]
        set -l repo_url $urls[$idx]
        set -l destination $target
        if test -z "$destination"
            set destination $name
        end
        if test -e "$destination"
            echo "gitget: target path '$destination' already exists" >&2
            return 1
        end
        echo "Cloning $repo_url → $destination"
        command git clone --depth=1 -- "$repo_url" "$destination"
        return $status
    end

    function __gitget_cleanup
        if functions -q __gitget_print
            functions -e __gitget_print
        end
        if functions -q __gitget_clone
            functions -e __gitget_clone
        end
        if functions -q __gitget_cleanup
            functions -e __gitget_cleanup
        end
    end

    set -l args $argv
    set -l mode list
    if test (count $args) -gt 0
        switch $args[1]
            case '--help' '-h'
                printf '%s\n' \
                    "Usage: gitget [--list] [--pick] [<repo|index> [target]]" \
                    "" \
                    "  gitget             List repositories as repo.git" \
                    "  gitget --pick      Interactive picker (numbered prompt)" \
                    "  gitget <repo>      Clone repository by name (with/without .git)" \
                    "  gitget <index>     Clone by numeric index from the list" \
                    "  gitget --list      Same as default listing" \
                    "  gitget --help      Show this help message"
                __gitget_cleanup
                return 0
            case '--pick' '-p'
                set mode pick
                set -e args[1]
            case '--list'
                set mode list
                set -e args[1]
            case '*'
                set mode direct
        end
    end

    if test "$mode" = "list"
        __gitget_print
        __gitget_cleanup
        return 0
    end

    if test "$mode" = "pick"
        for idx in (seq $repo_count)
            printf "%2d) %s\n" $idx "$labels[$idx]"
        end
        read -P "Select repo> " idx
        if not string match -rq '^[0-9]+$' -- $idx
            echo "gitget: invalid selection" >&2
            __gitget_cleanup
            return 1
        end
        if test $idx -lt 1 -o $idx -gt $repo_count
            echo "gitget: selection out of range" >&2
            __gitget_cleanup
            return 1
        end
        __gitget_clone $idx
        set -l exit_code $status
        __gitget_cleanup
        return $exit_code
    end

    # direct clone path
    if test (count $args) -eq 0
        __gitget_print
        __gitget_cleanup
        return 0
    end

    set -l first $args[1]
    set -l idx 0
    if string match -rq '^[0-9]+$' -- $first
        set idx $first
    else
        set -l normalized (string lower (string replace -r '\.git$' '' $first))
        for i in (seq $repo_count)
            if test (string lower -- $names[$i]) = $normalized
                set idx $i
                break
            end
        end
    end

    if test $idx -lt 1 -o $idx -gt $repo_count
        echo "gitget: repository '$first' not found under $user" >&2
        __gitget_cleanup
        return 1
    end

    set -l target ""
    if test (count $args) -ge 2
        set target $args[2]
    end

    __gitget_clone $idx $target
    set -l exit_code $status
    __gitget_cleanup
    return $exit_code
end
