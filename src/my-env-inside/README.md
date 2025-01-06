
# My Environment Inside

A feature catered to those who use the terminal and Neovim for their preferred IDE. Once installed, this will allow the user to directly shell into the dev container via the reference dev container CLI and have a working environment.

This feature adds a base installation of Neovim and can optionally refer to a dotfiles repository that uses chezmoi. By default, this will use the feature author's dotfiles repository. 

Using a dotfiles repository is the preferred approach to use since the feature will also run neovim *at build time* so Neovim plugins are downloaded and made part of the dev container image.

You can alternatively or in addition use this feature's capability of mounting the user's home directory and then either symbolically link or copy files via rsync from the home directory to the container user's environment. This process would overlay/hide (delete) any directories in the dev container that are both in the user's dotfiles repository and listed as directories to link or copy in favor of using the copied/linked directories. The disadvantage to this approach is everything is mounted at runtime, so any Neovim plugins would have to manually be updated at runtime each time the container is created if you want to use your local home directory.

## Example Usage

```json
"features": {
    "ghcr.io/frizzr/devcontainer-features/my-env-inside:1": { }
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| dotfileRepo | Change to your own or use mine. | string | "https://github.com/frizzr/dotfiles.git" |
| whichNeovim | Sets NVIM_APPNAME to this setting for the default neovim .config folder to use. | string | "nvim" |
| linkUserConfigDirs | Space-delimited list of directories relative to home directory to link to container home directory one time upon container creation. | string | "" |
| copyUserConfigDirs | Space-delimited list of directories relative to home directory to copy (with rsync) to container home directory each time you attach. | string | "" |



