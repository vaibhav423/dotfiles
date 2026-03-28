#==============================================================================
# GIT/GITHUB MANAGEMENT
#==============================================================================

usage_copilot() {
    local token=$(jq -r '.[].oauth_token' ~/.config/github-copilot/apps.json 2>/dev/null)
    [ -z "$token" ] && { echo "Error: Copilot token not found."; return 1; }
    curl -s -H "Authorization: Bearer $token" https://api.github.com/copilot_internal/user | \
        jq -r '.quota_snapshots.premium_interactions.percent_remaining | floor | "\(.)%"'
}

alias vglog='gh auth login'

gitmod() { git pull; git add .; git commit -m "new"; git push; }

_log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
_log_err()  { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

# --- Helpers ---
_get_token() { echo "$1" | jq -r '.gh_key'; }
_get_user()  { GH_TOKEN="$1" gh api user --jq '.login' 2>/dev/null; }

# --- Commands ---

gitlistf() { GH_TOKEN=$(_get_token "$1") gh repo list --limit 100; }
gitlist()  { GH_TOKEN=$(_get_token "$1") gh repo list --limit 100 --json name --jq '.[].name'; }

gitinsert() {
    # Usage: gitinsert <json> [public|private]
    local token=$(_get_token "$1")
    local user=$(_get_user "$token")
    local privacy=${2:-public}
    local project="${PWD##*/}"

    [ -z "$user" ] && { _log_err "Could not verify user."; return 1; }
    [ ! -d .git ] && { _log_info "Init repo..."; git init; }
    
    git remote remove origin 2>/dev/null
    _log_info "Creating --$privacy repo: $user/$project"
    
    if GH_TOKEN="$token" gh repo create "$project" "--$privacy" --source=. --remote=origin; then
        gauth "$1"
        git branch -M main
        git add .
        git diff --quiet --cached || git commit -m "Initial commit via gitinsert"
        _log_info "Pushing..."
        git push -u origin main
    fi
}

gitcl() {
    local token=$(_get_token "$1")
    local user=$(_get_user "$token")
    _log_info "Cloning $user/$2..."
    GH_TOKEN="$token" gh repo clone "$user/$2" && cd "$2" && gauth "$1"
}

gitcr() {
    local token=$(_get_token "$1")
    local privacy=${3:-public}
    _log_info "Creating $2 (--$privacy)..."
    GH_TOKEN="$token" gh repo create "$2" "--$privacy" --clone --add-readme && cd "$2" && gauth "$1"
}

gitfr() {
    _log_info "Forking $2..."
    GH_TOKEN=$(_get_token "$1") gh repo fork "$2" --clone && cd "$(basename "$2" .git)" && gauth "$1"
}

gitdel() {
    local token=$(_get_token "$1")
    GH_TOKEN="$token" gh repo delete "$(_get_user "$token")/$2" --yes
}

# Sync current repo identity based on provided JSON
gauth() {
    [ ! -d .git ] && { _log_err "Not a git repository."; return 1; }
    local name=$(echo "$1" | jq -r '.name')
    local mail=$(echo "$1" | jq -r '.mail')
    git config --local user.name "$name"
    git config --local user.email "$mail"
    echo -e "\033[0;32m[GIT]\033[0m Local identity set to: \033[1m$name <$mail>\033[0m"
}
