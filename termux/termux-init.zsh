
rm /data/data/com.termux/files/usr/etc/motd
curl -LO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.zip  && unzip JetBrainsMono.zip 'JetBrainsMonoNerdFont-Light.ttf' -d ~/.termux && mv ~/.termux/JetBrainsMonoNerdFont-Light.ttf ~/.termux/font.ttf && rm JetBrainsMono.zip
