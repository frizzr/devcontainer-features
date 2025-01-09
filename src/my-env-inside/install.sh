#!/bin/zsh

# set -x

FEATURE_DIR="${0:A:h}"
export _CONTAINER_USER_HOME=/home/$_CONTAINER_USER
CONTAINER_USER_GROUP=$(id -gn $_CONTAINER_USER)
cd $_CONTAINER_USER_HOME
CREATE_LINKS_TO_USER_HOME="/usr/local/share/link-to-home.sh"
SYNC_TO_USER_HOME="/usr/local/share/sync-to-home.sh"
P10K_SETUP_FILE="our-devcontainer-p10k.zsh"

# Copy our powerlevel10k prompt config to /tmp for use later
cp $FEATURE_DIR/$P10K_SETUP_FILE /tmp
chown ${_CONTAINER_USER}:${CONTAINER_USER_GROUP} /tmp/$P10K_SETUP_FILE

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

cd /tmp
apt-get update
apt-get -y install keychain build-essential libreadline-dev unzip pass
curl -L -R -O http://www.lua.org/ftp/lua-5.3.5.tar.gz
tar -zxf lua-5.3.5.tar.gz
cd lua-5.3.5
make linux test
make install
cd /tmp
curl -L -R -O https://luarocks.github.io/luarocks/releases/luarocks-3.11.1.tar.gz
tar -zxf luarocks-3.11.1.tar.gz
cd luarocks-3.11.1
./configure --with-lua-include=/usr/local/include
make
make install
cd /tmp
export ISTIO_VERSION="1.14.1"
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
cd istio-${ISTIO_VERSION}
cp -v bin/istioctl /usr/local/bin/

cd $_CONTAINER_USER_HOME
export PATH="$PATH:$_CONTAINER_USER_HOME/bin:$_CONTAINER_USER_HOME/.local/bin"
curl -LO --output-dir /tmp https://github.com/lsd-rs/lsd/releases/download/v1.1.5/lsd-musl_1.1.5_amd64.deb
apt install /tmp/lsd-musl_1.1.5_amd64.deb
curl -LO --output-dir /tmp https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-musl_0.24.0_amd64.deb
apt install /tmp/bat-musl_0.24.0_amd64.deb
curl -LO --output-dir /tmp https://github.com/junegunn/fzf/releases/download/v0.57.0/fzf-0.57.0-linux_amd64.tar.gz
tar -C /usr/local/bin -xzf /tmp/fzf-0.57.0-linux_amd64.tar.gz
curl -LO https://dl.k8s.io/release/$KUBECTLVERSION/bin/linux/amd64/kubectl
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm ./get_helm.sh

# Install neovim and run it to download needed neovim plugins at build time
curl -L -o /tmp/nvim-linux64.tar.gz https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
rm -rf /opt/nvim
tar -C /opt -xzf /tmp/nvim-linux64.tar.gz
export PATH="$PATH:/opt/nvim-linux64/bin"

chown -R ${_CONTAINER_USER}:${CONTAINER_USER_GROUP} "$_CONTAINER_USER_HOME"
###### START SECTION RUNNING AS SUPPLIED (NON-ROOT/ROOT) USER
sudo -u $_CONTAINER_USER /bin/zsh <<EOF
mkdir -p \$HOME/.config
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
# install krew for easy install of kubectl-related tools
(
set -x; cd "\$(mktemp -d)" &&
OS="\$(uname | tr '[:upper:]' '[:lower:]')" &&
ARCH="\$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
KREW="krew-\${OS}_\${ARCH}" &&
curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/\${KREW}.tar.gz" &&
tar zxvf "\${KREW}.tar.gz" &&
./"\${KREW}" install krew
)

export PATH="\${KREW_ROOT:-\$HOME/.krew}/bin:\$PATH"
kubectl krew update
kubectl krew install kc     # installs kubecm

pip install python-lsp-server

DOTFILE="$DOTFILEREPO"
if [ -n "\$DOTFILE" ]; then
    # Install chezmoi and get dotfiles. The default dotfiles is https://github.com/frizzr/dotfiles.git, which can
    # be used by anyone as an opinionated zsh terminal IDE with neovim.
    sh -c "\$(curl -fsLS get.chezmoi.io/lb)" -- init --apply "\$DOTFILE"
fi

ln -s \$HOME/.oh-my-zsh/custom/themes \$HOME/.config/zsh/custom/themes
ln -s \$HOME/.oh-my-zsh/custom/plugins \$HOME/.config/zsh/custom/plugins

if [[ -e \$HOME/.zshrc ]]; then
mv \$HOME/.zshrc \$HOME/microsoft.zshrc
fi
if [[ -e \$HOME/.zprofile ]]; then
mv \$HOME/.zprofile \$HOME/microsoft.zprofile
fi

source \$HOME/.config/zsh/.zshrc
git config --global --add safe.directory ${containerWorkspaceFolder}
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "\${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
# Move in our prompt config from /tmp
rm -f \$HOME/.config/zsh/.p10k.zsh
mv /tmp/$P10K_SETUP_FILE \$HOME/.config/zsh/.p10k.zsh

# Setup both neovim distros.
export PATH="\$PATH:/opt/nvim-linux64/bin"
NVIM_APPNAME=anvim nvim --headless +q   # stock AstroNvim
NVIM_APPNAME=rnvim nvim --headless +q   # The author's own nvim setup
cd \$HOME/.local/share/rnvim/lazy/coq_nvim
python3 -m coq deps
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

