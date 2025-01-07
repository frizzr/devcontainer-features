#!/bin/zsh

OURHOME="/root"
cd $OURHOME
CREATE_LINKS_TO_USER_HOME="/usr/local/share/link-to-home.sh"
SYNC_TO_USER_HOME="/usr/local/share/sync-to-home.sh"

touch $CREATE_LINKS_TO_USER_HOME
touch $SYNC_TO_USER_HOME
chmod 755 $CREATE_LINKS_TO_USER_HOME
chmod 755 $SYNC_TO_USER_HOME

mkdir -p ./.config

export PATH="$PATH:$OURHOME/bin:$OURHOME/.local/bin"
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh


# The default dotfiles repository assumes you will use /bin/zsh as your shell. It's opinionated.
if [ -n "$DOTFILEREPO" ]; then
    # Install chezmoi and get dotfiles. The default dotfiles is https://github.com/frizzr/dotfiles.git, which can
    # be used by anyone as an opinionated zsh terminal IDE with neovim.
    sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply "$DOTFILEREPO"
fi

# Git will be suspicious, so reassure it.
git config --global --add safe.directory ${containerWorkspaceFolder}

# Install neovim and run it to download needed neovim plugins at build time
curl -L -o /tmp/nvim-linux64.tar.gz https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
rm -rf /opt/nvim
tar -C /opt -xzf /tmp/nvim-linux64.tar.gz
export PATH="$PATH:/opt/nvim-linux64/bin"

# Setup both neovim distros.
NVIM_APPNAME=anvim nvim --headless +q
NVIM_APPNAME=rnvim nvim --headless +q

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


