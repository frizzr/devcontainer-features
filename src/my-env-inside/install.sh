#!/bin/zsh

cd $HOME
CREATE_LINKS_TO_USER_HOME="/usr/local/share/link-to-home.sh"
SYNC_TO_USER_HOME="/usr/local/share/sync-to-home.sh"

tee "$HOME/.zshenv" > /dev/null \
<< EOF
export XDG_CONFIG_HOME=\${XDG_CONFIG_HOME:=\${HOME}/.config}
export ZDOTDIR=\${ZDOTDIR:=\${XDG_CONFIG_HOME}/zsh}
EOF

sudo touch $CREATE_LINKS_TO_USER_HOME
sudo touch $SYNC_TO_USER_HOME
sudo chmod 755 $CREATE_LINKS_TO_USER_HOME
sudo chmod 755 $SYNC_TO_USER_HOME

mkdir -p ./.config

sudo apt update
export PATH="$PATH:$HOME/bin:$HOME/.local/bin"
sudo curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

sudo curl -LO --output-dir /tmp https://github.com/lsd-rs/lsd/releases/download/v1.1.5/lsd-musl_1.1.5_amd64.deb
sudo apt install /tmp/lsd-musl_1.1.5_amd64.deb
sudo curl -LO --output-dir /tmp https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-musl_0.24.0_amd64.deb
sudo apt install /tmp/bat-musl_0.24.0_amd64.deb
sudo curl -LO --output-dir /tmp https://github.com/junegunn/fzf/releases/download/v0.57.0/fzf-0.57.0-linux_amd64.tar.gz
sudo tar -C /usr/local/bin -xzf /tmp/fzf-0.57.0-linux_amd64.tar.gz

# Git will be suspicious, so reassure it.
git config --global --add safe.directory ${containerWorkspaceFolder}

# Install neovim and run it to download needed neovim plugins at build time
sudo curl -L -o /tmp/nvim-linux64.tar.gz https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf /tmp/nvim-linux64.tar.gz
export PATH="$PATH:/opt/nvim-linux64/bin"

# Install chezmoi as non-root
if [ -n "$DOTFILEREPO" ]; then
    # Install chezmoi and get dotfiles. The default dotfiles is https://github.com/frizzr/dotfiles.git, which can
    # be used by anyone as an opinionated zsh terminal IDE with neovim.
    sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply "$DOTFILEREPO"
fi

# Setup both neovim distros.
NVIM_APPNAME=anvim nvim --headless +q   # stock AstroNvim
NVIM_APPNAME=rnvim nvim --headless +q   # The author's own nvim setup

# Setup the script for linking directories from local home directory at runtime
if [ -n "$LINKUSERCONFIGDIRS" ]; then
sudo tee "$CREATE_LINKS_TO_USER_HOME" > /dev/null \
<< EOF
#!/bin/bash
read -r -a LINK_CONFIG_ARRAY <<<"$LINKUSERCONFIGDIRS"
for x in "\${LINK_CONFIG_ARRAY[@]}";
do
CURRENT="\$HOME/\$x"
if [[ ! -L \$CURRENT ]]; then
if [[ -e \$CURRENT ]]; then
rm -Rf \$CURRENT/*
fi
ln -s /usr/local/share/user.home/\$x \$CURRENT
fi
done
if [[ -e \$HOME/.config/*vim ]]; then
vim --headless +q
fi
EOF
sudo chmod 755 $CREATE_LINKS_TO_USER_HOME
fi

# Setup the script for copying directory contents from local home directory at runtime
if [ -n "$COPYUSERCONFIGDIRS" ]; then
sudo tee "$SYNC_TO_USER_HOME" > /dev/null \
<< EOF
#!/bin/bash
read -r -a COPY_CONFIG_ARRAY <<<"$COPYUSERCONFIGDIRS"
for x in "\${COPY_CONFIG_ARRAY[@]}";
do
CURRENT="\$HOME/\$x"
rsync -qr /usr/local/share/user.home/\$x/ \$CURRENT
done
if [[ -e \$HOME/.config/*nvim ]]; then
nvim --headless +q
fi
EOF
sudo chmod 755 $SYNC_TO_USER_HOME
fi

