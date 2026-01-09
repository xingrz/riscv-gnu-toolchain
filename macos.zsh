#!/bin/zsh
# Setup environment for building RISC-V GNU toolchain on macOS
# This script should be sourced: source macos.zsh

# Detect architecture (Apple Silicon vs Intel)
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

echo "Detected architecture: $ARCH"
echo "Using Homebrew prefix: $BREW_PREFIX"

# Add GNU tools to PATH (these take priority over BSD versions)
export PATH="$BREW_PREFIX/opt/bison/bin:$PATH"
export PATH="$BREW_PREFIX/opt/gawk/libexec/gnubin:$PATH"
export PATH="$BREW_PREFIX/opt/gnu-sed/libexec/gnubin:$PATH"
export PATH="$BREW_PREFIX/opt/make/libexec/gnubin:$PATH"
export PATH="$BREW_PREFIX/opt/m4/bin:$PATH"
export PATH="$BREW_PREFIX/opt/expat/bin:$PATH"

# Set MAKE variables to point to GNU make
export GNUMAKE="$BREW_PREFIX/opt/make/libexec/gnubin/make"
export MAKE="$BREW_PREFIX/opt/make/libexec/gnubin/make"

echo "GNU tools added to PATH"
echo "Use 'gmake' or the MAKE variable for building"