#!/usr/bin/env bash
# ============================================================================
# EECS 280 Native Linux Setup Verification & Fix Script
# ============================================================================
# This script checks that your Linux environment is configured correctly
# for EECS 280! It verifies: CLI tools (g++, make, gdb, tree, wget, git,
# rsync, ssh, python3), and VS Code.
#
# If something is missing, the script explains what it is and offers to
# install it for you.
#
# This is for students running native Linux (not WSL). If you're on
# Windows with WSL, the extension will automatically use the WSL script.
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
# Helper: Resolve VS Code CLI path
# ---------------------------------------------------------------------------
get_code_cli() {
    if command -v code &>/dev/null; then
        echo "code"
        return 0
    fi

    echo ""
    return 1
}

# ============================================================================
# Main
# ============================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         EECS 280 — Linux Setup Verification Tool             ║${NC}"
echo -e "${BOLD}║                                                              ║${NC}"
echo -e "${BOLD}║                       ${BLUE}${BOLD}/ᐠ - ˕ -マ ᶻ 𝗓 𐰁${NC}${BOLD}                       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════ by Alex Ni ════╝${NC}"
echo ""
echo -e "  Setup Guide: ${BLUE}https://eecs280staff.github.io/tutorials/${NC}"
echo ""

sleep 1

# Check distro and version
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "")
if [ -n "$UBUNTU_VERSION" ]; then
    DISTRO=$(lsb_release -ds 2>/dev/null || echo "Unknown")
    MAJOR_VERSION=$(echo "$UBUNTU_VERSION" | cut -d. -f1)
    if [ "$MAJOR_VERSION" -ge 24 ]; then
        pass "${DISTRO} (supported)"
    elif [ "$MAJOR_VERSION" -ge 22 ]; then
        warn "${DISTRO} — works, but consider upgrading to 24.04."
        info "The course tutorial uses Ubuntu 24.04."
    else
        fail "${DISTRO} — this version is too old and may cause issues."
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
        info "Fix: Upgrade to Ubuntu 24.04 or later."
    fi
elif command -v lsb_release &>/dev/null; then
    DISTRO=$(lsb_release -ds 2>/dev/null || echo "Unknown")
    info "Distribution: ${DISTRO}"
    warn "Could not parse version number. Make sure you're on Ubuntu 22.04+."
else
    warn "Could not detect Linux distribution."
    info "This script is designed for Ubuntu. Some checks may not apply."
fi
echo ""

# ── 1. C++ Compiler & Debugger ────────────────────────────────────────────
echo -e "${BOLD}[1/3] C++ Compiler & Debugger${NC}"
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

# ── 2. CLI Utilities ──────────────────────────────────────────────────────
echo -e "${BOLD}[2/3] CLI Utilities (tree, wget, git, rsync, ssh, python3)${NC}"
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

# ── 3. VS Code CLI ────────────────────────────────────────────────────────
echo -e "${BOLD}[3/3] VS Code 'code' command${NC}"
echo -e "      The 'code' command lets you open VS Code from the terminal."
echo -e "      It's also needed for managing extensions from the command line."
echo ""

CODE_CLI=""
CODE_CLI=$(get_code_cli) || true

if [ -n "$CODE_CLI" ]; then
    pass "'code' command is available."
else
    fail "'code' command not found."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    info "Make sure VS Code is installed."
    info "Download from: ${BLUE}https://code.visualstudio.com/download${NC}"
    info "After installing, open VS Code, press Ctrl+Shift+P, and run:"
    echo -e "      ${YELLOW}Shell Command: Install 'code' command in PATH${NC}"
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────
echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo ""
    echo -e "  ${GREEN}${BOLD}🎉 All checks passed! Your Linux environment is ready for EECS 280.${NC}"
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