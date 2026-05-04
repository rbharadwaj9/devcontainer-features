#!/bin/sh
set -e

VERSION=${VERSION:-v0.12.2}

echo "Installing Neovim $VERSION from prebuilt binary"

# map uname arch to Neovim release asset name
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  NVIM_ARCH="x86_64" ;;
    aarch64) NVIM_ARCH="arm64" ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

TARBALL="nvim-linux-${NVIM_ARCH}.tar.gz"
URL="https://github.com/neovim/neovim/releases/download/${VERSION}/${TARBALL}"

echo "Downloading $URL"

apt-get update
apt-get install -y --no-install-recommends curl ca-certificates
apt-get -y clean
rm -rf /var/lib/apt/lists/*

TMPDIR=$(mktemp -d)
curl -fsSL "$URL" -o "$TMPDIR/$TARBALL"

# extract — the tarball contains a single top-level dir (e.g. nvim-linux-x86_64/)
# stripping it so bin/nvim lands at /usr/local/bin/nvim
tar -C /usr/local --strip-components=1 -xzf "$TMPDIR/$TARBALL"

rm -rf "$TMPDIR"

echo "Neovim $(nvim --version | head -1) installed at $(command -v nvim)"

# Run headless setup if the nvim config is present (i.e. dotfiles feature ran first).
# Mirrors the Dockerfile sequence: stow → Lazy sync → TSInstall → Mason installs.
NVIM_CONFIG="${HOME:-/root}/.config/nvim"
if [ -d "$NVIM_CONFIG" ]; then
    echo "Neovim config found at $NVIM_CONFIG — running headless setup..."

    nvim_headless() {
        if [ "${TARGET_USER:-root}" = "root" ]; then
            HOME="${HOME:-/root}" nvim "$@"
        else
            su -s /bin/sh "$TARGET_USER" -c "HOME='$USER_HOME' nvim $*"
        fi
    }

    # Step 1: install / sync all lazy.nvim plugins synchronously
    nvim_headless --headless +"Lazy! sync" +qall 2>&1

    # Step 2: install TreeSitter parsers (from plugins/editor.lua ensure_installed list)
    nvim_headless --headless \
        +"TSInstall! c lua vim vimdoc query javascript html markdown markdown_inline python bash bibtex cmake cpp csv dockerfile git_config git_rebase gitcommit json make regex tmux yaml" \
        +"sleep 30" +qall 2>&1

    # Step 3: let Mason's ensure_installed run to completion (triggered on startup)
    # Servers: clangd ty ts_ls lua_ls lemminx jsonls yamlls neocmake texlab
    #          docker_language_server docker_compose_language_service
    nvim_headless --headless +"sleep 60" +qall 2>&1

    echo "Neovim headless setup complete."
else
    echo "No Neovim config found at $NVIM_CONFIG — skipping headless setup (run after dotfiles feature)."
fi
