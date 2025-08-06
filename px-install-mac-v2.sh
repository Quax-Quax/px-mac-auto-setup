#!/bin/bash

# Perple_X 7.1.13 for Mac - Auto Setup Script
#
# This script automates the installation of Homebrew, gfortran,
# and the compilation of Perple_X from the main branch.
#
# Usage:
# curl -sSL [Script URL] | bash
# or
# ./px-install-mac.sh [optional_install_directory]
#
# Author: Quax-Quax
# generated with Claude Sonnet 4, Gemini 2.5 Pro

set -euo pipefail # Fail on error, unset var, or pipe failure.

# --- Helper Functions for Logging ---
print_status() { echo -e "\n🔄 $1"; }
print_success() { echo "✅ $1"; }
print_error() { echo "❌ $1" >&2; }

# --- Initial Checks ---
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is for macOS only."
    exit 1
fi

if [[ $EUID -eq 0 ]]; then
    print_error "Do not run this script as root."
    exit 1
fi

# --- Main Logic ---
main() {
    # --- 1. Homebrew and gfortran Setup ---
    print_status "Setting up Homebrew and gfortran..."

    # Install Homebrew if not present
    if ! command -v brew &>/dev/null; then
        print_status "Installing Homebrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Get Homebrew's location and set it up for this session
    local brew_prefix
    brew_prefix=$(brew --prefix)
    eval "$("$brew_prefix/bin/brew" shellenv)"
    print_success "Homebrew is configured for this session."
    echo "   Path: $brew_prefix"

    # Add Homebrew to shell profile (.zshrc) if not already present
    local zshrc_path="$HOME/.zshrc"
    touch "$zshrc_path" # Ensure the file exists
    if ! grep -q "brew shellenv" "$zshrc_path"; then
        echo -e "\n# Homebrew" >> "$zshrc_path"
        echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> "$zshrc_path"
        print_success "Added Homebrew setup to $zshrc_path."
    fi

    # Install gfortran if not present
    if ! brew list gfortran &>/dev/null; then
        print_status "Installing gfortran..."
        brew install gfortran
        print_success "gfortran installed."
    else
        print_success "gfortran is already installed."
    fi
    
    # Verify gfortran command
    if ! command -v gfortran &>/dev/null; then
        print_error "gfortran command not found. Please check your Homebrew installation."
        exit 1
    fi

    # --- 2. Perple_X Setup and Build ---
    print_status "Setting up and building Perple_X v7.1.13..."

    # Define installation directory
    local perplex_version="7.1.13"
    local perplex_dir="${1:-$HOME/PerpleX_$perplex_version}"

    # Check if the target directory exists and is not empty to prevent data loss
    print_status "Preparing installation directory at $perplex_dir..."
    if [ -d "$perplex_dir" ] && [ "$(ls -A "$perplex_dir")" ]; then
        print_error "Directory '$perplex_dir' already exists and is not empty."
        print_error "Please specify a new directory or clear this one before running."
        exit 1
    fi

    # Create directory if it doesn't exist
    mkdir -p "$perplex_dir"
    cd "$perplex_dir"
    print_success "Installation directory is ready."

    # Clone the source code from the main branch
    print_status "Cloning Perple_X source code..."
    git clone --depth 1 https://github.com/jadconnolly/Perple_X.git .
    print_success "Source code cloned successfully."

    # Build from source
    local src_dir="$perplex_dir/src"
    if [[ ! -d "$src_dir" ]]; then
        print_error "Source directory not found: $src_dir"
        exit 1
    fi
    cd "$src_dir"

    if [[ ! -f "OSX_makefile2" ]]; then
        print_error "Makefile not found: OSX_makefile2"
        exit 1
    fi

    print_status "Building Perple_X with 8 parallel processes..."
    if ! make -f OSX_makefile2 -j8; then
        print_error "Perple_X build failed."
        exit 1
    fi
    print_success "Perple_X built successfully."

    # --- 3. Copy Executables ---
    print_status "Copying executables..."
    local executables="actcor convex fluids MC_fit pspts pstable pt2curv werami build ctransf frendly meemum pssect psvdraw vertex"
    
    # Create backup and final bin directories
    mkdir -p "$perplex_dir/bin_backup" "$perplex_dir/bin"

    for exe in $executables; do
        if [[ -f "$exe" ]]; then
            cp "$exe" "$perplex_dir/bin_backup/"
        else
            echo "⚠️  Warning: Executable '$exe' not found after build."
        fi
    done
    
    # Duplicate backup to the final bin directory
    cp -r "$perplex_dir/bin_backup/"* "$perplex_dir/bin/"
    print_success "Executables copied to $perplex_dir/bin/"

    # --- 4. Final Instructions ---
    echo -e "\n=================================================="
    echo "🎉 Perple_X Setup Complete! 🎉"
    echo "=================================================="
    echo "Installation Directory: $perplex_dir"
    echo "Executables:          $perplex_dir/bin/"
    echo ""
    echo "🔧 Next Steps:"
    echo "1. Open a new terminal window, or"
    echo "2. Run 'source ~/.zshrc' in your current terminal."
    echo ""
    echo "🧪 To run Perple_X:"
    echo "   cd $perplex_dir"
    echo "   ./bin/werami"
    echo "=================================================="
}

# Run the main function
main "$@"
