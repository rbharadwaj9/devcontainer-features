#!/bin/sh
set -e
echo "Activating feature 'dotfiles'"

REPO=${REPO:-"https://github.com/rbharadwaj9/dotfiles.git"}
TARGET_USER=${TARGETUSER:-root}
BRANCH=${BRANCH:-stow}

echo "Installing dotfiles from $REPO (branch: $BRANCH) for user $TARGET_USER"

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
    if [ -z "$USER_HOME" ]; then
        echo "Error: could not determine home directory for user '$TARGET_USER'" >&2
        exit 1
    fi
    DOTFILES_DIR="$USER_HOME/.dotfiles"
fi

echo "User home: $USER_HOME"
echo "Dotfiles directory: $DOTFILES_DIR"

# clone if needed
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone "$REPO" "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"
git checkout "$BRANCH"

# stow everything except .git and shell rc files (handled separately below)
stow -R --ignore='.git' --ignore='.bashrc' --ignore='.zshrc' --target="$USER_HOME" .

# For .bashrc and .zshrc: symlink them as .<shell>rc_custom and append a
# source line to the base rc file so the distro/common-utils version is preserved.
for shell in bash zsh; do
    dotfiles_rc="$DOTFILES_DIR/.${shell}rc"
    custom_file="$USER_HOME/.${shell}rc_custom"
    base_rc="$USER_HOME/.${shell}rc"
    source_line="[ -f \"\$HOME/.${shell}rc_custom\" ] && . \"\$HOME/.${shell}rc_custom\""

    if [ -f "$dotfiles_rc" ]; then
        ln -sf "$dotfiles_rc" "$custom_file"
        if [ -f "$base_rc" ]; then
            grep -qxF "$source_line" "$base_rc" || echo "$source_line" >> "$base_rc"
        else
            echo "$source_line" > "$base_rc"
        fi
        echo "Wired .${shell}rc_custom into $base_rc"
    fi
done

# fix permissions for non-root
if [ "$TARGET_USER" != "root" ]; then
    chown -R "$TARGET_USER:$TARGET_USER" "$DOTFILES_DIR"
fi

echo "Dotfiles installed successfully."
