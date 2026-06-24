#!/bin/bash
set -e
. dev-container-features-test-lib

# Runtime packages
check "ripgrep installed"  which rg
check "fzf installed"      which fzf
check "bat installed"      sh -c 'which bat || which batcat'
check "fd installed"       sh -c 'which fd || which fdfind'
check "direnv installed"   which direnv
check "zsh installed"      which zsh

# oh-my-zsh + plugins
check "oh-my-zsh installed"   test -d "$HOME/.oh-my-zsh"
check "p10k theme installed"  test -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
check "zsh-autosuggestions"   test -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
check "zsh-syntax-highlighting" test -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

# Dotfiles
check "dotfiles cloned" sh -c 'test -d "$HOME/.dotfiles" || test -d "/.dotfiles"'

# Shell rc wiring: at least one custom rc source line must be present
check "bashrc_custom wired" sh -c 'grep -q "bashrc_custom\|zshrc_custom" "$HOME/.bashrc" 2>/dev/null || grep -q "bashrc_custom\|zshrc_custom" "$HOME/.zshrc" 2>/dev/null'

reportResults
