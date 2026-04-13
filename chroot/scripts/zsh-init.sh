curl -s https://ohmyposh.dev/install.sh | bash -s

# Installing oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo ":: Installing oh-my-zsh"
    sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo ":: oh-my-zsh already installed"
fi

# Installing zsh-autosuggestions
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    echo ":: Installing zsh-autosuggestions"
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    echo ":: zsh-autosuggestions already installed"
fi

# Installing zsh-syntax-highlighting
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    echo ":: Installing zsh-syntax-highlighting"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
else
    echo ":: zsh-syntax-highlighting already installed"
fi

# Installing fast-syntax-highlighting
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/fast-syntax-highlighting" ]; then
    echo ":: Installing fast-syntax-highlighting"
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
else
    echo ":: fast-syntax-highlighting already installed"
fi
