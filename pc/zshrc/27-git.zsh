#==============================================================================
# GIT/GITHUB MANAGEMENT
#==============================================================================

# --- Helpers ---

_log_info() { echo -e "\033[0;32m[GIT]\033[0m $1"; }
_log_err()  { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

# Returns the JSON context string. If $1 is a JSON string, returns it, 
# otherwise returns the default_gh_user variable.
get_ctx() {
    if [[ "$1" == \{* ]]; then
        echo "$1"
    else
        echo "$default_gh_user"
    fi
}

get_token() {
    echo "$1" | jq -r '.gh_key'
}

get_username() {
    GH_TOKEN="$1" gh api user --jq '.login' 2>/dev/null
}

# --- Core Logic ---

# Sync current repo identity and remote based on the provided JSON context
gauth() {
    [ ! -d .git ] && { _log_err "Not a git repository."; return 1; }

    local ctx=$(get_ctx "$1")
    local name=$(echo "$ctx" | jq -r '.name')
    local mail=$(echo "$ctx" | jq -r '.mail')
    local token=$(get_token "$ctx")
    local user=$(get_username "$token")
    local repo_name=$(basename "$PWD")

    # Set identity
    git config --local user.name "$name"
    git config --local user.email "$mail"
    
    # Set remote URL with custom SSH alias
    if git remote | grep -q "^origin$"; then
        git remote set-url origin "$name:$user/$repo_name.git" 2>/dev/null
    else
        git remote add origin "$name:$user/$repo_name.git" 2>/dev/null
    fi
    
    _log_info "Identity: $name | Remote: $name:$user"
}

# --- Repository Commands ---

gitlist() {
    local ctx=$(get_ctx "$1")
    local token=$(get_token "$ctx")
    GH_TOKEN="$token" gh repo list --limit 100
}

gitlistf() {
    local ctx=$(get_ctx "$1")
    local token=$(get_token "$ctx")
    GH_TOKEN="$token" gh repo list --limit 100 --json name --jq '.[].name'
}

gitinsert() {
    local ctx=$(get_ctx "$1")
    local token=$(get_token "$ctx")
    local user=$(get_username "$token")
    
    # If first arg was context, the next arg is privacy. Otherwise first arg is privacy.
    local privacy="public"
    [[ "$1" == \{* ]] && privacy="${2:-public}" || privacy="${1:-public}"
    
    local repo_name=$(basename "$PWD")

    [ -d .git ] || { git init && git config --local init.defaultBranch main; }
    git remote remove origin 2>/dev/null
    
    if GH_TOKEN="$token" gh repo create "$repo_name" "--$privacy" --source=. --remote=origin; then
        gauth "$ctx"
        git branch -M main 2>/dev/null
        git config branch.main.remote origin
        git config branch.main.merge refs/heads/main
        git add .
        git diff --quiet --cached || git commit -m "new"
        git push -u origin main
    fi
}

gitcl() {
    local ctx=$(get_ctx "$1")
    local token=$(get_token "$ctx")
    local user=$(get_username "$token")
    
    # Get repo name from arguments
    local repo
    [[ "$1" == \{* ]] && repo="$2" || repo="$1"

    _log_info "Cloning $user/$repo..."
    if GH_TOKEN="$token" gh repo clone "$user/$repo"; then
        local actual_name=$(GH_TOKEN="$token" gh repo view "$user/$repo" --json name -q .name 2>/dev/null)
        cd "${actual_name:-$repo}" && gauth "$ctx"
    fi
}

gitcr() {
    local ctx=$(get_ctx "$1")
    local token=$(get_token "$ctx")
    
    local repo privacy
    if [[ "$1" == \{* ]]; then
        repo="$2"; privacy="${3:-public}"
    else
        repo="$1"; privacy="${2:-public}"
    fi

    _log_info "Creating $repo ($privacy)..."
    if GH_TOKEN="$token" gh repo create "$repo" "--$privacy" --clone --add-readme; then
        local actual_name=$(GH_TOKEN="$token" gh repo view "$repo" --json name -q .name 2>/dev/null)
        cd "${actual_name:-$repo}" && gauth "$ctx"
        git branch -M main 2>/dev/null
        git config branch.main.remote origin
        git config branch.main.merge refs/heads/main
        git pull origin main 2>/dev/null
    fi
}

gitfr() {
    local ctx=$(get_ctx "$1")
    local token=$(get_token "$ctx")
    local repo_url
    [[ "$1" == \{* ]] && repo_url="$2" || repo_url="$1"

    _log_info "Forking $repo_url..."
    if GH_TOKEN="$token" gh repo fork "$repo_url" --clone; then
        local actual_name=$(GH_TOKEN="$token" gh repo view "$repo_url" --json name -q .name 2>/dev/null)
        cd "${actual_name:-$(basename "$repo_url" .git)}" && gauth "$ctx"
    fi
}

gitdel() {
    local ctx=$(get_ctx "$1")
    local token=$(get_token "$ctx")
    local user=$(get_username "$token")
    local repo
    [[ "$1" == \{* ]] && repo="$2" || repo="$1"

    GH_TOKEN="$token" gh repo delete "$user/$repo" --yes
}

# --- Utils ---

gitmod() { 
    git pull && git add . && git commit -m "new" && git push 
}

usage_copilot() {
    local token=$(jq -r '.[].oauth_token' ~/.config/github-copilot/apps.json 2>/dev/null)
    [ -z "$token" ] && return 1
    curl -s -H "Authorization: Bearer $token" https://api.github.com/copilot_internal/user | \
        jq -r '.quota_snapshots.premium_interactions.percent_remaining | floor | "\(.)%"'
}

alias vglog='gh auth login'
