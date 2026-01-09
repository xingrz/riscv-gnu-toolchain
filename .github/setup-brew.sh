#!/bin/bash

set -e

# Install macOS prerequisites using Homebrew
# This script is for local development/manual builds
# GitHub Actions workflows handle dependency installation inline
# Based on README.md macOS section

echo "Installing Homebrew packages for RISC-V toolchain build..."

# Install dependencies
brew install python3 gawk gnu-sed make gmp mpfr libmpc isl zlib expat \
             texinfo flock libslirp ncurses ninja bison m4 wget \
             autoconf automake libtool patchutils dtc \
             pkg-config cmake glib

echo "Homebrew packages installed successfully"
echo ""
echo "IMPORTANT: To use the GNU tools, you need to update your PATH."
echo "Run 'source macos.zsh' to set up the environment for your current shell session."
echo "Or manually add the following to your shell profile:"

# Detect architecture and show appropriate paths
if [ "$(uname -m)" = "arm64" ]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

echo ""
echo "export PATH=\"$BREW_PREFIX/opt/bison/bin:\$PATH\""
echo "export PATH=\"$BREW_PREFIX/opt/gawk/libexec/gnubin:\$PATH\""
echo "export PATH=\"$BREW_PREFIX/opt/gnu-sed/libexec/gnubin:\$PATH\""
echo "export PATH=\"$BREW_PREFIX/opt/make/libexec/gnubin:\$PATH\""
echo "export PATH=\"$BREW_PREFIX/opt/m4/bin:\$PATH\""
echo "export PATH=\"$BREW_PREFIX/opt/expat/bin:\$PATH\""
echo ""
