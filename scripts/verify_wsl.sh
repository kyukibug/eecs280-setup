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

set -uo pipefail

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

# ── 1. WSL Environment ───────────────────────────────────────────────────
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

# Check WSL version via kernel string (reliable, no Windows interop needed)
# WSL 2 kernels contain "WSL2" or "microsoft-standard-WSL2" in uname -r.
# WSL 1 kernels contain "microsoft" but not "WSL2".
KERNEL_INFO=$(uname -r)
if echo "$KERNEL_INFO" | grep -qi "WSL2\|microsoft-standard-WSL2"; then
    pass "WSL version 2 detected."
    info "Kernel: ${KERNEL_INFO}"
elif echo "$KERNEL_INFO" | grep -qi "microsoft"; then
    # Has "microsoft" but not "WSL2" → likely WSL 1
    fail "WSL version 1 detected — you need version 2."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    info "Fix: Open PowerShell as administrator and run:"
    echo -e "      ${YELLOW}wsl --set-version Ubuntu-24.04 2${NC}"
    echo ""
else
    warn "Could not determine WSL version from kernel string."
    info "Kernel: ${KERNEL_INFO}"
    info "To verify, open PowerShell and run:"
    echo -e "      ${YELLOW}wsl -l -v${NC}"
    info "Make sure the VERSION column shows '2'."
fi

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "")
if [ -n "$UBUNTU_VERSION" ]; then
    DISTRO=$(lsb_release -ds 2>/dev/null || echo "Unknown")
    MAJOR_VERSION=$(echo "$UBUNTU_VERSION" | cut -d. -f1)
    if [ "$MAJOR_VERSION" -ge 24 ]; then
        pass "${DISTRO} (supported)"
    elif [ "$MAJOR_VERSION" -ge 22 ]; then
        warn "${DISTRO} — works, but consider upgrading to 24.04."
        info "The course tutorial uses Ubuntu 24.04."
        info "To upgrade, open PowerShell and run:"
        echo -e "      ${YELLOW}wsl --install -d Ubuntu-24.04${NC}"
    else
        fail "${DISTRO} — this version is too old and may cause issues."
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
        info "Fix: Install Ubuntu 24.04. Open PowerShell and run:"
        echo -e "      ${YELLOW}wsl --install -d Ubuntu-24.04${NC}"
    fi
else
    warn "Could not detect Ubuntu version."
    info "Make sure you're running Ubuntu (not another Linux distribution)."
fi

# Check for multiple Ubuntu installations (common source of confusion)
DISTRO_LIST=$(wsl.exe -l -q 2>/dev/null | tr -d '\r' | tr -d '\0' | grep -i "ubuntu" || echo "")
DISTRO_COUNT=$(echo "$DISTRO_LIST" | grep -c "." 2>/dev/null || echo "0")
if [ "$DISTRO_COUNT" -gt 1 ]; then
    echo ""
    warn "Multiple Ubuntu installations detected!"
    echo "$DISTRO_LIST" | while read -r line; do
        [ -n "$line" ] && info "  • $line"
    done
    info "You're currently in: ${WSL_DISTRO_NAME:-unknown}"
    info "Having multiple installs can cause confusion — you might"
    info "install tools in one but run VS Code in another."
    info "Consider removing extras in PowerShell:"
    echo -e "      ${YELLOW}wsl --unregister <name>${NC}"
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

# ── 4. VS Code CLI ────────────────────────────────────────────────────────
echo -e "${BOLD}[4/4] VS Code 'code' command${NC}"
echo -e "      The 'code' command lets you open VS Code from the terminal."
echo -e "      It's also needed for managing extensions from the command line."
echo ""

CODE_CLI=""
CODE_CLI=$(get_code_cli) || true

if [ -n "$CODE_CLI" ]; then
    pass "'code' command is available."
else
    fail "'code' command not found, and VS Code was not detected."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    info "Make sure VS Code is installed on Windows."
    info "Then open VS Code on Windows, install the 'WSL' extension,"
    info "and restart your Ubuntu terminal."
    echo ""
    info "Fix:"
    info "  1. Install VS Code from: ${BLUE}https://code.visualstudio.com/${NC}"
    info "  2. Open VS Code on Windows, install the 'WSL' extension."
    info "  3. Close and reopen your Ubuntu terminal."
    info "  4. Re-run this check."
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
    echo -e "  Re-run this check to verify everything is working:"
    echo -e "  ${BOLD}Ctrl+Shift+P → EECS 280: Verify Setup${NC}"
    echo -e "     ${BLUE}${BOLD}ദ്ദി(• ˕ •マ.ᐟ${NC}"
    echo ""
else
    echo ""
    echo -e "  ${RED}${BOLD}✘  ${ISSUES_FOUND} issue(s) found.${NC}"
    echo -e "  Follow the instructions above to fix them, then re-run:"
    echo -e "  ${BOLD}Ctrl+Shift+P → EECS 280: Verify Setup${NC}"
    echo -e "     ${BLUE}${BOLD}/ᐠ ╥ ˕ ╥マ${NC}"
    echo ""
fi
echo -e "  Questions? Visit: ${BLUE}https://eecs280staff.github.io/tutorials/${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo ""