#==============================================================================
# GIT/GITHUB MANAGEMENT
#==============================================================================
usage_copilot() {
    local token
    token=$(jq -r '.[].oauth_token' ~/.config/github-copilot/apps.json 2>/dev/null)
    
    if [ -z "$token" ]; then
        echo "Error: Copilot token not found."
        return 1
    fi

    curl -s -H "Authorization: Bearer $token" \
    https://api.github.com/copilot_internal/user | \
    jq -r '.quota_snapshots.premium_interactions.percent_remaining | floor | "\(.)%"'
}



# GitHub authentication
alias vglog='gh auth login'

# Quick git operations
gitmod(){ 
git pull 
git add .
git commit -m "new"
git push 
}


_get_gh_ctx() {
    if [[ "$1" == gho_* ]]; then
        echo "$1"
    else
        echo "$DEFAULT_GH_TOKEN"
    fi
}

# Helper for status messages
_log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
_log_err() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }
gitlistf() {
    local token=$(_get_gh_ctx "$1")
    GH_TOKEN="$token" gh repo list --limit 100 
}
gitlist() {
    local token=$(_get_gh_ctx "$1")
    GH_TOKEN="$token" gh repo list --limit 100 --json name --jq '.[].name'
}

gitinsert() {
    # Usage: gitinsert [token] [public|private]
    local token=$(_get_gh_ctx "$1")
    [[ "$1" == gho_* ]] && shift
    local privacy="--public"
    [[ "$1" == "private" ]] && privacy="--private"
    local project="${PWD##*/}"
    local user
    user=$(GH_TOKEN="$token" gh api user --jq '.login' 2>/dev/null)
    if [[ -z "$user" ]]; then
        _log_err "Could not verify GitHub user. Check your token."
        return 1
    fi
    # 1. Initialize git if it hasn't been already
    if [ ! -d .git ]; then
        _log_info "Initializing new Git repository..."
        git init
    fi
    # 2. Handle existing remotes (optional but recommended for robustness)
    # If 'origin' exists, gh repo create --source might conflict
    git remote remove origin 2>/dev/null
    _log_info "Creating $privacy repo: $user/$project"
    # 3. Create repo (removed deprecated --confirm)
    if GH_TOKEN="$token" gh repo create "$project" "$privacy" --source=. --remote=origin; then
        gauth
        git branch -M main
        git add .
        
        # Only commit if there are files to commit
        if ! git diff --quiet --cached; then
            git commit -m "Initial commit via gitinsert"
        fi
        
        _log_info "Pushing to main..."
        git push -u origin main
    fi
}
gitcl() {
    local token=$(_get_gh_ctx "$1")
    [[ "$1" == gho_* ]] && shift
    local repo="$1"
    local user
    user=$(GH_TOKEN="$token" gh api user --jq '.login' 2>/dev/null)
    
    _log_info "Cloning $user/$repo..."
    GH_TOKEN="$token" gh repo clone "$user/$repo" && cd "$repo" || return 1
    gauth
}
gitcr() {
    local token=$(_get_gh_ctx "$1")
    [[ "$1" == gho_* ]] && shift
    
    local project="$1"
    local privacy="--public"
    [[ "$2" == "private" ]] && privacy="--private"
    _log_info "Creating $project ($privacy)..."
    # Use --add-readme directly in gh repo create
    if GH_TOKEN="$token" gh repo create "$project" "$privacy" --clone --add-readme; then
        cd "$project" || return 1
    fi
    gauth
}
gitfr() {
    local token=$(_get_gh_ctx "$1")
    [[ "$1" == gho_* ]] && shift
    local repo_url="$1"
    _log_info "Forking $repo_url..."
    if GH_TOKEN="$token" gh repo fork "$repo_url" --clone; then
        local name
        name=$(basename "$repo_url" .git)
        cd "$name" || return 1
    fi
    gauth
}
gitdel() {
    local token=$(_get_gh_ctx "$1")
    [[ "$1" == gho_* ]] && shift
    local repo="$1"
    local user
    user=$(GH_TOKEN="$token" gh api user --jq '.login' 2>/dev/null)
    
    GH_TOKEN="$token" gh repo delete "$user/$repo" --yes
}

#==============================================================================
# MANUAL IDENTITY SYNC BASED ON REMOTE
#==============================================================================

# Sync current repo identity based on remote URL
gauth() {
    # Exit if not in a git repository
    if [ ! -d .git ]; then
        _log_err "Not a git repository."
        return 1
    fi
    
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null)
    
    # If no origin, check if we have any remote
    if [[ -z "$remote_url" ]]; then
        remote_url=$(git remote 2>/dev/null | xargs -I {} git remote get-url {} 2>/dev/null | head -n 1)
    fi
    
    if [[ -z "$remote_url" ]]; then
        _log_err "No remote found to match identity against."
        return 1
    fi
    
    local target_name target_email match_found=false
    
    # Try to extract 'host' or 'user' from URL
    # Handles: purr:org/repo, git@github.com:user/repo, https://github.com/user/repo
    local host_or_user
    if [[ "$remote_url" == *:* ]]; then
        # For SSH style (host:path or git@host:path)
        host_or_user=$(echo "$remote_url" | sed -E 's/.*(@|:\/\/)([^:/]+)[:\/].*/\2/')
        # If it didn't match the regex (e.g. host:path), just get everything before colon
        [[ "$host_or_user" == "$remote_url" ]] && host_or_user=$(echo "$remote_url" | cut -d':' -f1)
    else
        # For HTTP style (https://host/user/repo)
        host_or_user=$(echo "$remote_url" | cut -d'/' -f4)
    fi

    # 1. Try matching ~/.config/git/.gitconfig-<host_or_user>
    local config_file="$HOME/.config/git/.gitconfig-$host_or_user"
    
    # 2. Special case for your 'purr' identity if the URL contains the username
    if [[ ! -f "$config_file" ]] && [[ "$remote_url" == *purposeno968-ui* ]]; then
        config_file="$HOME/.config/git/.gitconfig-purr"
    fi

    if [[ -f "$config_file" ]]; then
        _log_info "Matching identity from $(basename "$config_file")..."
        target_name=$(git config -f "$config_file" user.name)
        target_email=$(git config -f "$config_file" user.email)
        match_found=true
    else
        # Fallback to default identity
        target_name="vaibhav"
        target_email="20vaibhav2007@gmail.com"
        _log_info "No specific config found for '$host_or_user'. Using default identity..."
    fi
    
    # Set the local configuration
    git config --local user.name "$target_name"
    git config --local user.email "$target_email"
    
    echo -e "\033[0;32m[GIT]\033[0m Local identity set to: \033[1m$target_name <$target_email>\033[0m"
}

