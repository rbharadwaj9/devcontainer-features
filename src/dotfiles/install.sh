#!/bin/sh
set -e
echo "Activating feature 'dotfiles'"

REPO=${REPO:-"https://github.com/rbharadwaj9/dotfiles.git"}
TARGET_USER=${TARGETUSER:-root}

echo "Installing dotfiles from $REPO for user $TARGET_USER"

# install dependencies
apt-get update
apt-get install -y git stow
apt-get -y clean
rm -rf /var/lib/apt/lists/*

# determine home + dotfiles location
if [ "$TARGET_USER" = "root" ]; then
    USER_HOME="/root"
    DOTFILES_DIR="/.dotfiles"
else
    USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    DOTFILES_DIR="$USER_HOME/.dotfiles"
fi

echo "User home: $USER_HOME"
echo "Dotfiles directory: $DOTFILES_DIR"

# clone if needed
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone "$REPO" "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"
git checkout stow

# stow all packages
stow --adopt .
git restore .

# fix permissions for non-root
if [ "$TARGET_USER" != "root" ]; then
    chown -R "$TARGET_USER:$TARGET_USER" "$DOTFILES_DIR"
fi

echo "Dotfiles installed successfully."
