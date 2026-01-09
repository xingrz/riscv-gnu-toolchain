#!/bin/bash

set -e

# Install macOS prerequisites using Homebrew
# Based on README.md macOS section

echo "Installing Homebrew packages for RISC-V toolchain build..."

# Install dependencies
brew install python3 gawk gnu-sed make gmp mpfr libmpc isl zlib expat \
             texinfo flock libslirp ncurses ninja bison m4 wget \
             autoconf automake libtool patchutils device-tree-compiler \
             pkg-config cmake glib

# Setup PATH for GNU tools based on architecture
# Detect architecture and set Homebrew prefix
if [ "$(uname -m)" = "arm64" ]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

export PATH="$BREW_PREFIX/opt/bison/bin:$PATH"
export PATH="$BREW_PREFIX/opt/gawk/libexec/gnubin:$PATH"
export PATH="$BREW_PREFIX/opt/gnu-sed/libexec/gnubin:$PATH"
export PATH="$BREW_PREFIX/opt/make/libexec/gnubin:$PATH"
export PATH="$BREW_PREFIX/opt/m4/bin:$PATH"
export PATH="$BREW_PREFIX/opt/expat/bin:$PATH"

echo "Homebrew packages installed successfully"
echo "PATH updated for GNU tools (using $BREW_PREFIX)"
