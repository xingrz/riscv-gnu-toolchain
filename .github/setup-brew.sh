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

# Setup PATH for GNU tools
export PATH="/opt/homebrew/opt/bison/bin:$PATH"
export PATH="/opt/homebrew/opt/gawk/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/m4/bin:$PATH"

# For Intel Macs, use /usr/local instead of /opt/homebrew
if [ "$(uname -m)" = "x86_64" ]; then
    export PATH="/usr/local/opt/bison/bin:$PATH"
    export PATH="/usr/local/opt/gawk/libexec/gnubin:$PATH"
    export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
    export PATH="/usr/local/opt/make/libexec/gnubin:$PATH"
    export PATH="/usr/local/opt/m4/bin:$PATH"
fi

echo "Homebrew packages installed successfully"
echo "PATH updated for GNU tools"
