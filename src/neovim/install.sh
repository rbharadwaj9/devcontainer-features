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
