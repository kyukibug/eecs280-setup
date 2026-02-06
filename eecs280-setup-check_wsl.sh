#!/usr/bin/env bash
# ============================================================================
# EECS 280 WSL (Windows) Setup Verification & Fix Script
# ============================================================================
# This script checks that your WSL Ubuntu environment is configured
# correctly for EECS 280!
# It verifies: WSL version, CLI tools (g++, make, gdb, tree, wget, git,
# rsync, ssh, python3), and VS Code with required extensions.
#
# If something is missing, the script explains what it is and offers to
# install it for you.
#
# References:
#   WSL CLI Tools: https://eecs280staff.github.io/tutorials/setup_wsl.html
#   VS Code Setup: https://eecs280staff.github.io/tutorials/setup_vscode_wsl.html
#
# Author: Alex Ni (axni@umich.edu)
# Built with assistance from Claude Opus 4.6
# ============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors & formatting
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

pass()  { echo -e "  ${GREEN}✔${NC} $1"; }
fail()  { echo -e "  ${RED}✘${NC} $1"; }
info()  { echo -e "  ${BLUE}ℹ${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }

# Track overall status
ISSUES_FOUND=0
FIXES_APPLIED=0

# ---------------------------------------------------------------------------
# Helper: prompt user y/n
# ---------------------------------------------------------------------------
ask_install() {
    local tool_name="$1"
    echo ""
    read -r -p "    Would you like me to install ${tool_name} for you? [y/n] " yn
    case "$yn" in
        [Yy]* ) return 0 ;;
        * )     info "Skipping ${tool_name} installation. You can install it manually later."
                return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# Helper: Resolve VS Code CLI path (WSL)
# ---------------------------------------------------------------------------
get_code_cli() {
    # In WSL, 'code' is a shell script wrapper provided by the VS Code
    # WSL extension. It lives in the Windows PATH exposed to WSL.
    if command -v code &>/dev/null; then
        echo "code"
        return 0
    fi

    # Not found
    echo ""
    return 1
}

# ============================================================================
# Main
# ============================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          EECS 280 — WSL Setup Verification Tool              ║${NC}"
echo -e "${BOLD}║                                                              ║${NC}"
echo -e "${BOLD}║                       ${BLUE}${BOLD}/ᐠ - ˕ -マ ᶻ 𝗓 𐰁${NC}${BOLD}                       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════ by Alex Ni ════╝${NC}"
echo ""
echo -e "  WSL Setup:   ${BLUE}https://eecs280staff.github.io/tutorials/setup_wsl.html${NC}"
echo -e "  VS Code:     ${BLUE}https://eecs280staff.github.io/tutorials/setup_vscode_wsl.html${NC}"
echo ""

sleep 1

# ── 0. Sanity check: are we actually in WSL? ─────────────────────────────
if ! grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
    echo ""
    warn "It doesn't look like you're running this inside WSL/Ubuntu."
    info "This script is meant to be run in an Ubuntu terminal on Windows (WSL)."
    info "If you're on macOS, use the macOS verification script instead."
    echo ""
    read -r -p "    Continue anyway? [y/n] " yn
    case "$yn" in
        [Yy]* ) ;;
        * ) echo ""; info "Exiting."; exit 0 ;;
    esac
    echo ""
fi

# ── 1. WSL Version ───────────────────────────────────────────────────────
echo -e "${BOLD}[1/4] WSL Environment${NC}"
echo -e "      WSL (Windows Subsystem for Linux) runs an Ubuntu Linux"
echo -e "      environment on your Windows machine for C++ development."
echo ""

# Check that we're running as a normal user, not root
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" = "root" ]; then
    fail "You are logged in as 'root' — this is not correct."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    info "You should be logged in as a regular user, not root."
    info "Fix: Open PowerShell as administrator and reinstall Ubuntu:"
    echo -e "      ${YELLOW}wsl --unregister Ubuntu-24.04${NC}"
    echo -e "      ${YELLOW}wsl --install -d Ubuntu-24.04${NC}"
    echo -e "      Then create a new user account when prompted."
    echo ""
else
    pass "Logged in as user '${CURRENT_USER}' (not root)."
fi

# Check WSL version (should be 2)
WSL_VERSION=""
if [ -f /proc/version ]; then
    # Try to detect WSL version from environment
    if [ -n "${WSL_DISTRO_NAME:-}" ]; then
        # We're in WSL — try to get version via interop
        WSL_VERSION=$(wsl.exe -l -v 2>/dev/null | grep -i "${WSL_DISTRO_NAME}" | awk '{print $NF}' | tr -d '[:space:]' 2>/dev/null || echo "")
    fi
fi

if [ "$WSL_VERSION" = "2" ]; then
    pass "WSL version 2 detected."
elif [ "$WSL_VERSION" = "1" ]; then
    fail "WSL version 1 detected — you need version 2."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    info "Fix: Open PowerShell as administrator and run:"
    echo -e "      ${YELLOW}wsl --set-version Ubuntu-24.04 2${NC}"
    echo ""
else
    # Couldn't determine version, but we're running — probably fine
    warn "Could not determine WSL version (this is usually fine)."
    info "To verify, open PowerShell and run:"
    echo -e "      ${YELLOW}wsl -l -v${NC}"
    info "Make sure the VERSION column shows '2'."
fi

# Check Ubuntu version
if command -v lsb_release &>/dev/null; then
    DISTRO=$(lsb_release -ds 2>/dev/null || echo "Unknown")
    info "Distribution: ${DISTRO}"
fi
echo ""

# ── 2. C++ Compiler & Debugger ────────────────────────────────────────────
echo -e "${BOLD}[2/4] C++ Compiler & Debugger${NC}"
echo -e "      g++ compiles your C++ code into programs. gdb is the debugger"
echo -e "      that lets you step through code and find bugs."
echo ""

COMPILER_OK=true

# g++
if command -v g++ &>/dev/null; then
    pass "g++ is installed."
    compiler_version=$(g++ --version 2>&1 | head -n1)
    info "Compiler: ${compiler_version}"
else
    fail "g++ is NOT installed."
    COMPILER_OK=false
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# gdb
if command -v gdb &>/dev/null; then
    pass "gdb is installed."
    gdb_version=$(gdb --version 2>&1 | head -n1)
    info "Debugger: ${gdb_version}"
else
    fail "gdb is NOT installed."
    COMPILER_OK=false
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# make
if command -v make &>/dev/null; then
    pass "make is installed."
else
    fail "make is NOT installed."
    COMPILER_OK=false
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

if ! $COMPILER_OK; then
    echo ""
    info "Fix: Install the missing tools with:"
    echo -e "      ${YELLOW}sudo apt update && sudo apt install g++ make gdb${NC}"
    echo ""
    if ask_install "g++, make, and gdb"; then
        info "Running apt install... You may be prompted for your password."
        echo ""
        sudo apt update && sudo apt install -y g++ make gdb
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
        pass "Compiler and debugger tools installed."
    fi
fi
echo ""

# ── 3. CLI Utilities ──────────────────────────────────────────────────────
echo -e "${BOLD}[3/4] CLI Utilities (tree, wget, git, rsync, ssh, python3)${NC}"
echo -e "      Command-line programs used throughout the course for viewing"
echo -e "      files, downloading content, version control, and more."
echo ""

APT_PACKAGES_NEEDED=()

# tree
if command -v tree &>/dev/null; then
    pass "tree is installed. (Displays directory structures in a visual tree format.)"
else
    fail "tree is NOT installed."
    info "tree displays your project folder structure visually — helpful for debugging."
    APT_PACKAGES_NEEDED+=("tree")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# wget
if command -v wget &>/dev/null; then
    pass "wget is installed. (Downloads files from the web via the command line.)"
else
    fail "wget is NOT installed."
    info "wget is used to download starter files and project resources."
    APT_PACKAGES_NEEDED+=("wget")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# git
if command -v git &>/dev/null; then
    pass "git is installed. (Version control system for tracking code changes.)"
else
    fail "git is NOT installed."
    info "git tracks changes to your code and is required for project submission."
    APT_PACKAGES_NEEDED+=("git")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# rsync
if command -v rsync &>/dev/null; then
    pass "rsync is installed. (Efficiently syncs and transfers files.)"
else
    fail "rsync is NOT installed."
    info "rsync is used to sync files between directories and remote servers."
    APT_PACKAGES_NEEDED+=("rsync")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# ssh
if command -v ssh &>/dev/null; then
    pass "ssh is installed. (Secure remote login to other computers.)"
else
    fail "ssh is NOT installed."
    info "ssh lets you connect to remote servers like CAEN Linux."
    APT_PACKAGES_NEEDED+=("ssh")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# python3
if command -v python3 &>/dev/null; then
    pass "python3 is installed. (Python interpreter, used by some course tools.)"
else
    fail "python3 is NOT installed."
    info "python3 is used by some course tools and scripts."
    APT_PACKAGES_NEEDED+=("python3")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

if [ ${#APT_PACKAGES_NEEDED[@]} -gt 0 ]; then
    echo ""
    pkg_list="${APT_PACKAGES_NEEDED[*]}"
    info "Fix: Install missing tools with apt:"
    echo -e "      ${YELLOW}sudo apt update && sudo apt install ${pkg_list}${NC}"
    echo ""
    if ask_install "${pkg_list}"; then
        info "Installing ${pkg_list} via apt... You may be prompted for your password."
        echo ""
        sudo apt update && sudo apt install -y "${APT_PACKAGES_NEEDED[@]}"
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
        pass "Installed: ${pkg_list}"
    fi
fi
echo ""

# ── 4. VS Code & Extensions ──────────────────────────────────────────────
echo -e "${BOLD}[4/4] VS Code & Extensions${NC}"
echo -e "      VS Code is your code editor. The WSL extension connects it to"
echo -e "      your Ubuntu environment, and the C/C++ extension provides"
echo -e "      IntelliSense and debugging support."
echo ""

CODE_CLI=""
CODE_CLI=$(get_code_cli) || true

if [ -n "$CODE_CLI" ]; then
    pass "'code' command is available in WSL."
    info "(This means VS Code + the WSL extension are working.)"
    echo ""

    # Check for required extensions
    INSTALLED_EXTENSIONS=$("$CODE_CLI" --list-extensions 2>/dev/null || echo "")

    REQUIRED_EXTENSIONS=(
        "ms-vscode-remote.remote-wsl"    # WSL extension
        "ms-vscode.cpptools"             # C/C++ by Microsoft
    )
    EXTENSION_NAMES=(
        "WSL (ms-vscode-remote.remote-wsl) — connects VS Code to your Ubuntu environment"
        "C/C++ (ms-vscode.cpptools) — provides IntelliSense and debugging for C++"
    )

    MISSING_EXTENSIONS=()

    for i in "${!REQUIRED_EXTENSIONS[@]}"; do
        ext_id="${REQUIRED_EXTENSIONS[$i]}"
        ext_name="${EXTENSION_NAMES[$i]}"
        if echo "$INSTALLED_EXTENSIONS" | grep -qi "^${ext_id}$"; then
            pass "${ext_name}"
        else
            fail "${ext_name}"
            MISSING_EXTENSIONS+=("$ext_id")
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    done

    if [ ${#MISSING_EXTENSIONS[@]} -gt 0 ]; then
        echo ""
        info "Fix: Install missing extensions with:"
        for ext in "${MISSING_EXTENSIONS[@]}"; do
            echo -e "      ${YELLOW}code --install-extension ${ext}${NC}"
        done
        echo ""
        if ask_install "the missing VS Code extension(s)"; then
            for ext in "${MISSING_EXTENSIONS[@]}"; do
                info "Installing ${ext}..."
                "$CODE_CLI" --install-extension "$ext" --force 2>/dev/null
            done
            FIXES_APPLIED=$((FIXES_APPLIED + 1))
            pass "Extensions installed. You may need to reload VS Code."
        fi
    fi
else
    fail "'code' command not found in WSL."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo ""
    info "This usually means one of:"
    info "  1. VS Code is not installed on Windows."
    info "  2. The WSL extension is not installed in VS Code."
    info "  3. You need to restart your terminal after installing VS Code."
    echo ""
    info "Fix:"
    info "  1. Install VS Code from: ${BLUE}https://code.visualstudio.com/${NC}"
    info "  2. Open VS Code on Windows, install the 'WSL' extension."
    info "  3. Close and reopen your Ubuntu terminal."
    info "  4. Re-run this script."
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────
echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo ""
    echo -e "  ${GREEN}${BOLD}🎉 All checks passed! Your WSL environment is ready for EECS 280.${NC}"
    echo -e "     ${BLUE}${BOLD}/ᐠ > ˕ <マ ₊˚⊹♡${NC}"
    echo ""
elif [ "$FIXES_APPLIED" -gt 0 ]; then
    echo ""
    echo -e "  ${YELLOW}${BOLD}⚙  Fixes were applied.${NC}"
    echo -e "  Please ${BOLD}close and reopen your terminal${NC}, then run this script"
    echo -e "  again to verify everything is working."
    echo -e "     ${BLUE}${BOLD}ദ്ദി(• ˕ •マ.ᐟ${NC}"
    echo ""
else
    echo ""
    echo -e "  ${RED}${BOLD}✘  ${ISSUES_FOUND} issue(s) found.${NC}"
    echo -e "  Follow the instructions above to fix them, then re-run this script."
    echo -e "     ${BLUE}${BOLD}/ᐠ ╥ ˕ ╥マ${NC}"
    echo ""
fi
echo -e "  Questions? Visit: ${BLUE}https://eecs280staff.github.io/tutorials/${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo ""
