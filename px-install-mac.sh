#!/bin/bash

# Perple_X for Mac - Auto Setup Script with Version Control
#
# This script automates the installation of Homebrew, gfortran,
# and the compilation of a specified version of Perple_X.
#
# Usage:
# ./px-install-mac.sh [version|head]
# e.g., ./px-install-mac.sh v7.1.13
#       ./px-install-mac.sh head
#
# When you get a 'permission denied' error,
# 1.  grant it execute permissions, or
# 2.  use 'bash ./px-install-mac-v3.sh [version|head]'   
#
# Author: Quax-Quax & Coding Partner

set -euo pipefail # Fail on error, unset var, or pipe failure.

# --- Helper Functions for Logging ---
print_status() { echo -e "\n🔄 $1"; }
print_success() { echo "✅ $1"; }
print_error() { echo "❌ $1" >&2; }

# --- Usage Function ---
usage() {
    echo "Usage: $0 [version|head]"
    echo "  version: A valid Perple_X release tag (e.g., v7.1.13)."
    echo "  head:    Install the latest version from the main branch."
    echo
    echo "Example: $0 v7.1.13"
}

# --- Version Check Functions ---
# Fetches available release tags from GitHub API
get_available_versions() {
    curl -s "https://api.github.com/repos/jadconnolly/Perple_X/releases" | \
    grep '"tag_name":' | \
    sed -E 's/.*"([^"]+)".*/\1/'
}

# Validates if the requested version exists
validate_version() {
    local version_to_check="$1"
    
    if [[ "$version_to_check" == "head" ]]; then
        return 0 # 'head' is always valid
    fi

    print_status "Validating version '$version_to_check'..."
    local available_versions
    available_versions=$(get_available_versions)

    if ! echo "$available_versions" | grep -q "^$version_to_check$"; then
        print_error "Version '$version_to_check' not found."
        echo "Available versions are:"
        echo "$available_versions"
        exit 1
    fi
    print_success "Version '$version_to_check' is valid."
}

# Checks if the version is buildable (v7.1.12 or newer)
check_buildability() {
    local version_to_check="$1"
    
    if [[ "$version_to_check" == "head" ]]; then
        return 0 # Assume 'head' is always buildable
    fi

    # Extract numeric parts: v7.1.13 -> 7 1 13
    local major minor patch
    IFS='.' read -r major minor patch <<< "${version_to_check#v}"

    # Compare with v7.1.12
    if (( major < 7 )) || \
       (( major == 7 && minor < 1 )) || \
       (( major == 7 && minor == 1 && patch < 12 )); then
        print_error "Version $version_to_check is older than v7.1.12 and cannot be built with this script due to missing makefiles."
        exit 1
    fi
}


# --- gfortran Setup ---
gfortran_setup() {
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
}

# --- Main Logic ---
main() {
    # --- 0. Initial Checks ---
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    local version="$1"

    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is for macOS only."
        exit 1
    fi

    if [[ $EUID -eq 0 ]]; then
        print_error "Do not run this script as root."
        exit 1
    fi

    # --- 1. Version Validation ---
    validate_version "$version"
    check_buildability "$version"

    # --- 2. Homebrew and gfortran Setup ---
    local gfortran_flag
    if ! command -v gfortran &>/dev/null; then
        print_error "gfortran command not found."
        print_status "Setting up Homebrew and gfortran..."
        gfortran_setup
        gfortran_flag="1"
    else
        print_success "gfortran is already installed."
        gfortran_flag="0"
    fi

    # --- 3. Perple_X Setup and Build ---
    print_status "Setting up and building Perple_X ($version)..."

    # Create a temporary directory for download and cleanup on exit
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf -- "$tmp_dir"' EXIT

    # Define URLs and installation directory
    local download_url
    local perplex_dir="$HOME/Perple_X/$version"
    
    if [[ "$version" == "head" ]]; then
        download_url="https://github.com/jadconnolly/Perple_X/archive/refs/heads/main.tar.gz"
    else
        download_url="https://api.github.com/repos/jadconnolly/Perple_X/tarball/$version"
    fi

    # Check if the target directory exists
    if [ -d "$perplex_dir" ]; then
        print_error "Directory '$perplex_dir' already exists."
        print_error "Please remove it or choose a different version before running."
        exit 1
    fi

    # Download source code
    print_status "Downloading source code from $download_url..."
    if ! curl -L "$download_url" -o "$tmp_dir/perplex.tar.gz"; then
        print_error "Download failed. Please check the version and your internet connection."
        exit 1
    fi
    print_success "Source code downloaded."

    # Extract source code
    print_status "Extracting source code..."
    mkdir -p "$perplex_dir"
    # The --strip-components=1 flag removes the top-level directory from the archive
    if ! tar -xzf "$tmp_dir/perplex.tar.gz" -C "$perplex_dir" --strip-components=1; then
        print_error "Extraction failed. The downloaded file might be corrupt."
        exit 1
    fi
    print_success "Source code extracted to $perplex_dir"

    # Build from source
    local src_dir="$perplex_dir/src"
    if [[ ! -d "$src_dir" ]]; then
        print_error "Source directory not found: $src_dir"
        exit 1
    fi
    cd "$src_dir"

    if [[ ! -f "OSX_makefile2" ]]; then
        print_error "Makefile not found: OSX_makefile2. This version might not be buildable on macOS."
        exit 1
    fi

    print_status "Building Perple_X with 8 parallel processes..."
    if ! make -f OSX_makefile2 -j8; then
        print_error "Perple_X build failed."
        exit 1
    fi
    print_success "Perple_X built successfully."

    # --- 4. Copy Executables ---
    print_status "Copying executables..."
    local executables="actcor convex fluids MC_fit pspts pstable pt2curv werami build ctransf frendly meemum pssect psvdraw vertex"
    
    mkdir -p "$perplex_dir/bin" "$perplex_dir/bin_backup"

    for exe in $executables; do
        if [[ -f "$exe" ]]; then
            cp "$exe" "$perplex_dir/bin/"
        else
            echo "⚠️  Warning: Executable '$exe' not found after build."
        fi
    done
    print_success "Executables copied to $perplex_dir/bin/"
    cp -r "$perplex_dir/bin/"* "$perplex_dir/bin_backup/"
    print_success "Excutables backuped to $perplex_dir/bin_backup/"

    # --- 5. Final Instructions ---
    echo -e "\n=================================================="
    echo "🎉 Perple_X ($version) Setup Complete! 🎉"
    echo "=================================================="
    echo "Installation Directory: $perplex_dir"
    echo "Executables:          $perplex_dir/bin/"
    echo ""
    if [[gfortran_flag == "1"]]; then
        echo "🔧 Next Steps:"
        echo "1. Open a new terminal window, or"
        echo "2. Run 'source ~/.zshrc' in your current terminal."
        echo ""
    fi
    echo "🧪 To run Perple_X:"
    echo "   cd $perplex_dir"
    echo "   ./bin/werami"
    echo "=================================================="
}

# Run the main function, passing all script arguments
main "$@"
