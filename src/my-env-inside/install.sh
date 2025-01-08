#!/bin/zsh

CONTAINER_USER_GROUP=$(id -gn $_CONTAINER_USER)
cd $_CONTAINER_USER_HOME
CREATE_LINKS_TO_USER_HOME="/usr/local/share/link-to-home.sh"
SYNC_TO_USER_HOME="/usr/local/share/sync-to-home.sh"

tee "$_CONTAINER_USER_HOME/.zshenv" > /dev/null \
<< EOF
export XDG_CONFIG_HOME=\${XDG_CONFIG_HOME:=\${HOME}/.config}
export ZDOTDIR=\${ZDOTDIR:=\${XDG_CONFIG_HOME}/zsh}
EOF
chown ${_CONTAINER_USER}:${CONTAINER_USER_GROUP} "$_CONTAINER_USER_HOME/.zshenv"

touch $CREATE_LINKS_TO_USER_HOME
touch $SYNC_TO_USER_HOME
chmod 755 $CREATE_LINKS_TO_USER_HOME
chmod 755 $SYNC_TO_USER_HOME

apt update
export PATH="$PATH:$HOME/bin:$HOME/.local/bin"
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

curl -LO --output-dir /tmp https://github.com/lsd-rs/lsd/releases/download/v1.1.5/lsd-musl_1.1.5_amd64.deb
apt install /tmp/lsd-musl_1.1.5_amd64.deb
curl -LO --output-dir /tmp https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-musl_0.24.0_amd64.deb
apt install /tmp/bat-musl_0.24.0_amd64.deb
curl -LO --output-dir /tmp https://github.com/junegunn/fzf/releases/download/v0.57.0/fzf-0.57.0-linux_amd64.tar.gz
tar -C /usr/local/bin -xzf /tmp/fzf-0.57.0-linux_amd64.tar.gz

# Install neovim and run it to download needed neovim plugins at build time
curl -L -o /tmp/nvim-linux64.tar.gz https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
rm -rf /opt/nvim
tar -C /opt -xzf /tmp/nvim-linux64.tar.gz
export PATH="$PATH:/opt/nvim-linux64/bin"

###### START SECTION RUNNING AS SUPPLIED (NON-ROOT/ROOT) USER
sudo -u $_CONTAINER_USER /bin/zsh <<EOF
mkdir -p \$HOME/.config
DOTFILE="$DOTFILEREPO"
if [ -n "\$DOTFILE" ]; then
    # Install chezmoi and get dotfiles. The default dotfiles is https://github.com/frizzr/dotfiles.git, which can
    # be used by anyone as an opinionated zsh terminal IDE with neovim.
    sh -c "\$(curl -fsLS get.chezmoi.io/lb)" -- init --apply "\$DOTFILE"
fi

git config --global --add safe.directory ${containerWorkspaceFolder}

if [[ -e \$HOME/.zshrc ]]; then
mv \$HOME/.zshrc \$HOME/microsoft.zshrc
fi
if [[ -e \$HOME/.zprofile ]]; then
mv \$HOME/.zprofile \$HOME/microsoft.zprofile
fi
# Setup both neovim distros.
export PATH="\$PATH:/opt/nvim-linux64/bin"
NVIM_APPNAME=anvim nvim --headless +q   # stock AstroNvim
NVIM_APPNAME=rnvim nvim --headless +q   # The author's own nvim setup
EOF

# Setup the script for linking directories from local home directory at runtime
if [ -n "$LINKUSERCONFIGDIRS" ]; then
tee "$CREATE_LINKS_TO_USER_HOME" > /dev/null \
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
chmod 755 $CREATE_LINKS_TO_USER_HOME
fi

# Setup the script for copying directory contents from local home directory at runtime
if [ -n "$COPYUSERCONFIGDIRS" ]; then
tee "$SYNC_TO_USER_HOME" > /dev/null \
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
chmod 755 $SYNC_TO_USER_HOME
fi

