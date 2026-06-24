#!/bin/sh
set -e
echo "Activating feature 'dotfiles'"

REPO=${REPO:-"https://github.com/rbharadwaj9/dotfiles.git"}
TARGET_USER="${TARGETUSER:-${_REMOTE_USER:-root}}"
BRANCH=${BRANCH:-stow}

echo "Installing dotfiles from $REPO (branch: $BRANCH) for user $TARGET_USER"

# Helper: run a shell command as the target user
run_as_user() {
    if [ "$TARGET_USER" = "root" ]; then
        sh -c "$1"
    else
        su -s /bin/sh "$TARGET_USER" -c "$1"
    fi
}

# Install dependencies + runtime packages expected by the dotfiles configs
apt-get update
apt-get install -y \
    git stow curl \
    zsh \
    ripgrep fzf bat fd-find \
    direnv
apt-get -y clean
rm -rf /var/lib/apt/lists/*

# Ubuntu ships bat as 'batcat' and fd as 'fdfind'; create canonical aliases
[ -f /usr/bin/batcat ]  && ln -sf /usr/bin/batcat  /usr/local/bin/bat
[ -f /usr/bin/fdfind ]  && ln -sf /usr/bin/fdfind  /usr/local/bin/fd

# Determine home + dotfiles location
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

echo "User home:         $USER_HOME"
echo "Dotfiles directory: $DOTFILES_DIR"

# Clone dotfiles if needed
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone "$REPO" "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"
git checkout "$BRANCH"

# Install oh-my-zsh as the target user so ~/.oh-my-zsh lands in the right home.
# We back up .zshrc first because the installer rewrites it; our dotfiles handle
# zsh init via .zshrc_custom, so we restore the original afterwards.
if command -v zsh > /dev/null 2>&1; then
    OMZ_DIR="$USER_HOME/.oh-my-zsh"
    if [ ! -d "$OMZ_DIR" ]; then
        OMZ_INSTALLER=$(mktemp /tmp/omz-install.XXXXXX.sh)
        curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh \
            -o "$OMZ_INSTALLER"
        chmod +x "$OMZ_INSTALLER"

        # Back up .zshrc so the installer doesn't clobber the distro version
        ZSHRC_BACKUP=""
        if [ -f "$USER_HOME/.zshrc" ]; then
            ZSHRC_BACKUP=$(mktemp /tmp/zshrc-backup.XXXXXX)
            cp "$USER_HOME/.zshrc" "$ZSHRC_BACKUP"
        fi

        run_as_user "HOME='$USER_HOME' ZSH='$OMZ_DIR' RUNZSH=no CHSH=no sh '$OMZ_INSTALLER' --unattended"
        rm -f "$OMZ_INSTALLER"

        # Restore original .zshrc; .zshrc_custom wired below handles our config
        if [ -n "$ZSHRC_BACKUP" ]; then
            cp "$ZSHRC_BACKUP" "$USER_HOME/.zshrc"
            rm -f "$ZSHRC_BACKUP"
        fi
    fi

    # Install zsh plugins and powerlevel10k theme into the custom directory
    ZSH_CUSTOM="$OMZ_DIR/custom"
    for entry in \
        "zsh-users/zsh-autosuggestions:plugins/zsh-autosuggestions" \
        "zsh-users/zsh-syntax-highlighting:plugins/zsh-syntax-highlighting" \
        "romkatv/powerlevel10k:themes/powerlevel10k"; do
        repo="${entry%%:*}"
        dest="${entry##*:}"
        if [ ! -d "$ZSH_CUSTOM/$dest" ]; then
            git clone --depth=1 "https://github.com/$repo" "$ZSH_CUSTOM/$dest"
        fi
    done
fi

# Stow everything except shell rc files (handled separately below)
stow -R --ignore='.git' --ignore='.bashrc' --ignore='.zshrc' --target="$USER_HOME" .

# For .bashrc and .zshrc: symlink the dotfiles version as .<shell>rc_custom and
# append a source line to the base rc file, preserving whatever common-utils wrote.
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

# Fix ownership for non-root
if [ "$TARGET_USER" != "root" ]; then
    chown -R "$TARGET_USER:$TARGET_USER" "$DOTFILES_DIR"
    [ -d "$USER_HOME/.oh-my-zsh" ] && chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME/.oh-my-zsh"
fi

echo "Dotfiles installed successfully."
