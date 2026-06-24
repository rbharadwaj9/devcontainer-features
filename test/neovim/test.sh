#!/bin/bash
set -e
. dev-container-features-test-lib

check "nvim binary exists"    which nvim
check "nvim runs"             nvim --version
check "nvim version matches"  sh -c 'nvim --version | head -1 | grep -qE "^NVIM v"'

reportResults
