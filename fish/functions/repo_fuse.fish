function repo_fuse -d "Clone and bootstrap curated repositories"
    set -l manifest ~/.config/fish/repos/catalog.toml
    set -l history_file ~/.local/share/repo-fuse/history.tsv
    set -l log_root ~/.local/share/repo-fuse/logs

    if not type -q python3
        echo "repo_fuse: python3 is required but was not found" >&2
        return 1
    end

    if not type -q git
        echo "repo_fuse: git is required but was not found" >&2
        return 1
    end

    argparse -n repo_fuse \
        'h/help' \
        'l/list' \
        'm/manifest=' \
        'f/force' \
        'n/no-setup' \
        'd/directory=' \
        'g/github-user=' \
        's/source=' \
        'T/github-token-env=' \
        'N/no-forks' \
        -- $argv
    set -l argparse_status $status
    if test $argparse_status -ne 0
        return $argparse_status
    end

    if set -q _flag_help
        printf '%s\n' \
            "Usage: repo_fuse [options] [repo-name] [target-dir]" \
            "" \
            "Options:" \
            "  -h, --help            Show this help message" \
            "  -l, --list            Show catalog entries without cloning" \
            "  -m, --manifest PATH   Use a custom manifest file" \
            "  -f, --force           Allow cloning into an existing non-empty directory" \
            "  -n, --no-setup        Skip running setup commands after clone" \
            "  -d, --directory DIR   Override target directory name" \
            "  -g, --github-user U   Pull repositories from GitHub user/owner U" \
            "  -s, --source MODE     Choose catalog: manifest (default) or github" \
            "  -T, --github-token-env VAR  Environment variable to read GitHub token from (default GITHUB_TOKEN)" \
            "  -N, --no-forks        Hide forked repositories from GitHub listings"
        return 0
    end
    if set -q _flag_manifest
        set manifest $_flag_manifest
    end

    set -l source manifest
    if set -q _flag_source
        set source (string lower -- $_flag_source)
    end

    set -l github_user
    if set -q _flag_github_user
        set github_user $_flag_github_user
    else if set -q REPO_FUSE_GITHUB_USER
        set github_user $REPO_FUSE_GITHUB_USER
    end

    set -l github_token_env GITHUB_TOKEN
    if set -q _flag_github_token_env
        set github_token_env $_flag_github_token_env
    else if set -q REPO_FUSE_GITHUB_TOKEN_ENV
        set github_token_env $REPO_FUSE_GITHUB_TOKEN_ENV
    end

    if set -q _flag_github_user
        set source github
    end

    set -l include_forks 1
    if set -q _flag_no_forks
        set include_forks 0
    else if set -q REPO_FUSE_NO_FORKS
        switch (string lower -- $REPO_FUSE_NO_FORKS)
            case 1 on yes true
                set include_forks 0
        end
    end

    switch $source
        case manifest github
        case '*'
            echo "repo_fuse: unsupported source '$source'" >&2
            return 1
    end

    if test "$source" = "manifest"
        if not test -f "$manifest"
            if test -n "$github_user"
                set source github
            else
                echo "repo_fuse: manifest not found at $manifest" >&2
                return 1
            end
        end
    else if test "$source" = "github"
        if test -z "$github_user"
            echo "repo_fuse: --github-user is required for GitHub source (or set REPO_FUSE_GITHUB_USER)" >&2
            return 1
        end
    end

    mkdir -p "$log_root"
    mkdir -p (command dirname "$history_file")

    set -l sep (printf '\x1f')
    set -l repo_lines

    if test "$source" = "github"
        if type -q gh
            set repo_lines (python3 -c '
import json, subprocess, sys

user = sys.argv[1]
include_forks = sys.argv[2] == "1"

cmd = [
    "gh", "repo", "list", user,
    "--limit", "1000",
    "--json", "name,description,sshUrl,isFork,defaultBranchRef,pushedAt,primaryLanguage,owner",
]
completed = subprocess.run(cmd, capture_output=True, text=True)
if completed.returncode != 0:
    stderr = completed.stderr.strip() or "repo_fuse: gh repo list failed"
    sys.stderr.write(stderr + "\n")
    sys.exit(completed.returncode or 1)

try:
    data = json.loads(completed.stdout or "[]")
except json.JSONDecodeError:
    sys.stderr.write("repo_fuse: failed to parse gh repo list JSON\n")
    sys.exit(1)

count = 0
user_lower = user.lower()
for entry in data:
    if entry.get("isFork") and not include_forks:
        continue
    owner = (entry.get("owner") or {}).get("login") or ""
    if owner and owner.lower() != user_lower and not include_forks:
        continue
    name = entry.get("name") or ""
    if not name:
        continue
    desc = (entry.get("description") or "").replace("\n", " ").strip()
    url = entry.get("sshUrl") or ""
    if not url:
        continue
    branch = ""
    default_branch = entry.get("defaultBranchRef") or {}
    if isinstance(default_branch, dict):
        branch = default_branch.get("name") or ""
    language = ""
    primary_language = entry.get("primaryLanguage")
    if isinstance(primary_language, dict):
        language = primary_language.get("name") or ""
    pushed = entry.get("pushedAt") or ""

    notes_parts = []
    if entry.get("isFork"):
        notes_parts.append("fork")
    if language:
        notes_parts.append(language)
    if pushed:
        notes_parts.append(f"updated:{pushed[:10]}")
    notes = " ".join(notes_parts)

    print("\t".join([name, desc, url, branch, "", notes]))
    count += 1

if count == 0:
    sys.exit(2)
' "$github_user" "$include_forks")
        else
            set repo_lines (python3 -c '
import os, sys, json
import urllib.request
import urllib.error

user = sys.argv[1]
token_env = sys.argv[2]
include_forks = sys.argv[3] == "1"
token = os.environ.get(token_env, "")

per_page = 100
page = 1
printed = 0

def emit(entry):
    global printed
    if (entry.get("fork") or False) and not include_forks:
        return
    name = entry.get("name") or ""
    if not name:
        return
    desc = (entry.get("description") or "").replace("\n", " ").strip()
    ssh_url = entry.get("ssh_url") or ""
    https_url = entry.get("clone_url") or ""
    clone = ssh_url or https_url
    if not clone:
        return
    branch = entry.get("default_branch") or ""
    language = entry.get("language") or ""
    starred = entry.get("stargazers_count") or 0
    pushed = entry.get("pushed_at") or ""
    notes_parts = []
    if entry.get("fork"):
        notes_parts.append("fork")
    if language:
        notes_parts.append(language)
    if pushed:
        notes_parts.append(f"updated:{pushed[:10]}")
    if starred:
        notes_parts.append(f"★{starred}")
    notes = " ".join(notes_parts)
    print("\t".join([name, desc, clone, branch, "", notes]))
    printed += 1

try:
    while True:
        url = f"https://api.github.com/users/{user}/repos?per_page={per_page}&page={page}&type=owner&sort=updated"
        req = urllib.request.Request(url)
        req.add_header("User-Agent", "repo-fuse")
        if token:
            req.add_header("Authorization", f"token {token}")
        with urllib.request.urlopen(req) as resp:
            payload = json.load(resp)
        if not payload:
            break
        for item in payload:
            emit(item)
        if len(payload) < per_page:
            break
        page += 1
except urllib.error.HTTPError as exc:
    sys.stderr.write(f"repo_fuse: GitHub API error {exc.code}: {exc.reason}\n")
    sys.exit(1)
except urllib.error.URLError as exc:
    sys.stderr.write(f"repo_fuse: GitHub API network error: {exc.reason}\n")
    sys.exit(1)

if printed == 0:
    sys.exit(2)
' "$github_user" "$github_token_env" "$include_forks")
        end
        set repo_status $status
    else
        set repo_lines (python3 -c '
import sys
try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib  # type: ignore

manifest_path = sys.argv[1]
include_forks = sys.argv[2] == "1"

with open(manifest_path, "rb") as fh:
    data = tomllib.load(fh)

entries = data.get("repo", [])
for idx, entry in enumerate(entries, 1):
    if entry.get("fork") and not include_forks:
        continue
    name = entry.get("name") or f"repo-{idx}"
    desc = entry.get("description", "").replace("\n", " ").strip()
    url = entry.get("url", "")
    branch = entry.get("branch", "")
    setup = entry.get("setup") or []
    extra = entry.get("notes", "")
    setup_clean = "\x1f".join(cmd.strip() for cmd in setup if cmd.strip())
    print("\t".join([name, desc, url, branch, setup_clean, extra]))
' "$manifest" "$include_forks")
        set repo_status $status
    end
    if test $repo_status -ne 0
        if test "$source" = "github"
            if test $repo_status -eq 2
                echo "repo_fuse: no repositories available for GitHub user $github_user" >&2
                return 1
            else
                return 1
            end
        else
            echo "repo_fuse: failed to read manifest $manifest" >&2
            return 1
        end
    end

    set -l repo_count (count $repo_lines)
    if test $repo_count -eq 0
        if test "$source" = "github"
            echo "repo_fuse: no repositories available for GitHub user $github_user" >&2
        else
            echo "repo_fuse: manifest $manifest does not contain any [[repo]] entries" >&2
        end
        return 1
    end
    if test $repo_count -eq 1
        if test -z "$repo_lines[1]"
            if test "$source" = "github"
                echo "repo_fuse: no repositories available for GitHub user $github_user" >&2
            else
                echo "repo_fuse: manifest $manifest does not contain any [[repo]] entries" >&2
            end
            return 1
        end
    end

    set -l names
    set -l descriptions
    set -l urls
    set -l branches
    set -l setup_lists
    set -l notes_list

    for line in $repo_lines
        set -l fields (string split -- \t $line)
        set -a names $fields[1]
        set -a descriptions $fields[2]
        set -a urls $fields[3]
        set -a branches $fields[4]
        set -a setup_lists $fields[5]
        set -a notes_list $fields[6]
    end

    if set -q _flag_list
        printf '%-20s %-50s %s\n' "NAME" "DESCRIPTION" "URL"
        for idx in (seq (count $names))
            printf '%-20s %-50s %s\n' "$names[$idx]" "$descriptions[$idx]" "$urls[$idx]"
        end
        return 0
    end

    set -l rest $_flag_rest
    set -l selected_name
    set -l target_dir

    if test (count $rest) -gt 0
        set selected_name $rest[1]
        if test (count $rest) -gt 1
            set target_dir $rest[2]
        end
    end

    if not set -q selected_name
        set -l menu_items
        for idx in (seq (count $names))
            set -l item $names[$idx]
            if test -n "$descriptions[$idx]"
                set item "$item\t$descriptions[$idx]"
            end
            if test -n "$notes_list[$idx]"
                set item "$item\t$notes_list[$idx]"
            end
            set -a menu_items "$item"
        end

        if type -q fzf
            set -l selection (printf '%s\n' -- $menu_items | fzf --with-nth=1,2 --prompt='repo> ' --ansi)
            if test -z "$selection"
                echo "repo_fuse: no selection made" >&2
                return 1
            end
            set selected_name (string split -- \t $selection)[1]
        else
            echo "Select a repository:"
            for idx in (seq (count $menu_items))
                printf '%2d) %s\n' $idx (string replace --regex '\t' ' — ' "$menu_items[$idx]")
            end
            read -P "repo_fuse choice> " selection_index
            if not string match -rq '^[0-9]+$' -- $selection_index
                echo "repo_fuse: invalid selection" >&2
                return 1
            end
            if test $selection_index -lt 1 -o $selection_index -gt (count $names)
                echo "repo_fuse: selection out of range" >&2
                return 1
            end
            set selected_name $names[$selection_index]
        end
    end

    set -l idx 0
    for candidate_idx in (seq (count $names))
        if test "$names[$candidate_idx]" = "$selected_name"
            set idx $candidate_idx
            break
        end
    end
    if test $idx -eq 0
        echo "repo_fuse: repo '$selected_name' not found in manifest" >&2
        return 1
    end

    set -l repo_url $urls[$idx]
    if test -z "$repo_url"
        echo "repo_fuse: repo '$selected_name' is missing a url" >&2
        return 1
    end

    set -l repo_branch $branches[$idx]

    if not set -q target_dir
        set target_dir $selected_name
        read -P "Target directory [$target_dir]: " target_override
        if test -n "$target_override"
            set target_dir $target_override
        end
    end

    if test -d "$target_dir"
        set -l contents (command ls -A -- "$target_dir" ^/dev/null)
        if test -n "$contents"
            if not set -q _flag_force
                echo "repo_fuse: directory '$target_dir' exists and is not empty (use --force to override)" >&2
                return 1
            end
        end
    else if test -e "$target_dir"
        echo "repo_fuse: path '$target_dir' already exists and is not a directory" >&2
        return 1
    end

    set -l clone_args --depth=1
    if test -n "$repo_branch"
        set clone_args $clone_args --branch $repo_branch
    end

    echo "→ Cloning $repo_url"
    command git clone $clone_args -- "$repo_url" "$target_dir"
    set -l clone_status $status
    if test $clone_status -ne 0
        echo "repo_fuse: git clone failed (status $clone_status)" >&2
        set -l timestamp (date "+%Y-%m-%dT%H:%M:%S")
        set -l failed_path $target_dir
        if not string match -q '/*' -- $failed_path
            set failed_path (pwd)/$failed_path
        end
        printf "%s\t%s\t%s\tclone_failed\n" "$timestamp" "$selected_name" "$failed_path" >> "$history_file"
        return $clone_status
    end

    set -l setup_cmds
    if test -n "$setup_lists[$idx]"
        set setup_cmds (string split -- $sep $setup_lists[$idx])
    end

    set -l timestamp (date "+%Y%m%dT%H%M%S")
    set -l log_file $log_root/$timestamp-$selected_name.log
    set -l resolved_dir $target_dir
    if not string match -q '/*' -- $resolved_dir
        set resolved_dir (pwd)/$resolved_dir
    end
    printf "repo: %s\ntarget: %s\nstarted: %s\n\n" "$selected_name" "$resolved_dir" (date "+%Y-%m-%d %H:%M:%S") > "$log_file"

    set -l setup_failed 0
    if set -q _flag_no_setup
        echo "→ Skipping setup steps (--no-setup)"
    else if test (count $setup_cmds) -gt 0
        pushd "$target_dir" >/dev/null
        for cmd in $setup_cmds
            if test -z "$cmd"
                continue
            end
            echo "→ $cmd"
            printf "→ %s\n" "$cmd" >> "$log_file"
            set -l step_status 0
            begin
                eval $cmd
                set step_status $status
            end 2>&1 | tee -a "$log_file"
            printf "exit %d\n\n" $step_status >> "$log_file"
            if test $step_status -ne 0
                echo "repo_fuse: setup command failed ('$cmd')" >&2
                set setup_failed 1
                break
            end
        end
        popd >/dev/null
    else
        echo "→ No setup steps defined"
    end

    set -l final_status success
    if test $setup_failed -eq 1
        set final_status setup_failed
    end
    printf "completed: %s\nstatus: %s\n" (date "+%Y-%m-%d %H:%M:%S") "$final_status" >> "$log_file"

    set -l history_path $target_dir
    if not string match -q '/*' -- $history_path
        set history_path (pwd)/$history_path
    end
    set -l history_stamp (date "+%Y-%m-%dT%H:%M:%S")
    printf "%s\t%s\t%s\t%s\n" "$history_stamp" "$selected_name" "$history_path" "$final_status" >> "$history_file"

    if test $setup_failed -eq 0
        echo "✓ $selected_name ready in $history_path"
        if type -q code
            read -P "Launch VS Code here? [y/N] " launch_code
            if string match -iq 'y*' -- $launch_code
                code "$target_dir"
            end
        end
        return 0
    else
        echo "⚠ setup encountered an error; see $log_file" >&2
        return 1
    end
end
