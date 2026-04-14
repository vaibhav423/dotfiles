
source <(fzf --zsh)
eval "$(zoxide init zsh)"
export FZF_COMPLETION_TRIGGER=',,'

# # terminal-wakatime setup
# export PATH="$HOME/.wakatime:$PATH"
# eval "$(terminal-wakatime init)"
export TERM=xterm-256color
source ~/Water/crap/python/bin/activate
#export PATH="/usr/bin:$PATH"
export LIBVIRT_DEFAULT_URI='qemu:///system'
# export NVM_DIR="$HOME/.config/nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

source ~/.secrets
