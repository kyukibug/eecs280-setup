#!/usr/bin/env bash
# ============================================================================
# EECS 280 macOS Setup Verification & Fix Script
# ============================================================================
# This script checks that your Mac is configured correctly for EECS 280!
# It verifies: Xcode CLI Tools, Homebrew, tree, wget, git, and the VS Code
# 'code' command.
#
# If something is missing, the script explains what it is and offers to
# install it for you.
#
# References:
#   macOS CLI Tools: https://eecs280staff.github.io/tutorials/setup_macos.html
#   VS Code Setup:   https://eecs280staff.github.io/tutorials/setup_vscode_macos.html
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
# Helper: Resolve Homebrew path (Apple Silicon vs Intel)
# ---------------------------------------------------------------------------
get_brew_path() {
    if [ -x "/opt/homebrew/bin/brew" ]; then
        echo "/opt/homebrew/bin/brew"
    elif [ -x "/usr/local/bin/brew" ]; then
        echo "/usr/local/bin/brew"
    else
        echo ""
    fi
}

ensure_brew_in_path() {
    # If brew is already in PATH, nothing to do.
    if command -v brew &>/dev/null; then
        return 0
    fi

    local brew_bin
    brew_bin="$(get_brew_path)"
    if [ -n "$brew_bin" ]; then
        eval "$("$brew_bin" shellenv)"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Helper: Resolve VS Code CLI path
# ---------------------------------------------------------------------------
get_code_cli() {
    # 1. Already in PATH
    if command -v code &>/dev/null; then
        echo "code"
        return 0
    fi

    # 2. Common macOS application locations
    local candidates=(
        "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    )
    for candidate in "${candidates[@]}"; do
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done

    # Not found
    echo ""
    return 1
}

# ============================================================================
# Main
# ============================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         EECS 280 — macOS Setup Verification Tool             ║${NC}"
echo -e "${BOLD}║                                                              ║${NC}"
echo -e "${BOLD}║                       ${BLUE}${BOLD}/ᐠ - ˕ -マ ᶻ 𝗓 𐰁${NC}${BOLD}                       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════ by Alex Ni ════╝${NC}"
echo ""
echo -e "  CLI Tools:  ${BLUE}https://eecs280staff.github.io/tutorials/setup_macos.html${NC}"
echo -e "  VS Code:    ${BLUE}https://eecs280staff.github.io/tutorials/setup_vscode_macos.html${NC}"
echo ""

sleep 1


# ── 0. Sanity check: are we actually on macOS? ─────────────────────────────
if [ "$(uname -s)" != "Darwin" ]; then
    warn "This script is for macOS, but you appear to be on $(uname -s)."
    info "If you're on Windows/WSL, use the WSL verification script instead."
    echo ""
    read -r -p "    Continue anyway? [y/n] " yn
    case "$yn" in
        [Yy]* ) ;;
        * ) echo ""; info "Exiting."; exit 0 ;;
    esac
fi

# ── 1. Xcode Command Line Tools ───────────────────────────────────────────
echo -e "${BOLD}[1/4] Xcode Command Line Tools (C++ compiler)${NC}"
echo -e "      Provides g++/clang — the compiler that turns your C++ code"
echo -e "      into programs your Mac can run."
echo ""

if xcode-select -p &>/dev/null && command -v g++ &>/dev/null; then
    pass "Xcode CLI Tools are installed."
    # Show version for reference
    compiler_version=$(g++ --version 2>&1 | head -n1)
    info "Compiler: ${compiler_version}"
else
    fail "Xcode Command Line Tools are NOT installed."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    info "Fix: Run the following command, then click 'Install' in the dialog:"
    echo -e "      ${YELLOW}xcode-select --install${NC}"
    echo ""
    if ask_install "Xcode Command Line Tools"; then
        info "Opening the Xcode CLI Tools installer..."
        info "A dialog box will appear — click 'Install' and wait for it to finish."
        info "After installation completes, please re-run this verification script."
        xcode-select --install 2>/dev/null || true
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
        echo ""
        warn "The installer is running in the background. Once it finishes,"
        warn "close and reopen your terminal, then re-run this check."
        echo ""
        # We can't continue meaningfully until CLT finishes, but we'll keep
        # checking other items so the student gets a full picture.
    fi
fi
echo ""

# ── 2. Homebrew ───────────────────────────────────────────────────────────
echo -e "${BOLD}[2/4] Homebrew (package manager)${NC}"
echo -e "      Homebrew lets you easily install developer tools on macOS,"
echo -e "      similar to an app store for command-line programs."
echo ""

BREW_OK=false
if ensure_brew_in_path; then
    pass "Homebrew is installed and in your PATH."
    brew_version=$(brew --version 2>&1 | head -n1)
    info "Version: ${brew_version}"
    BREW_OK=true
else
    brew_bin="$(get_brew_path)"
    if [ -n "$brew_bin" ]; then
        # Brew is installed but not in PATH
        fail "Homebrew is installed but NOT in your shell PATH."
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
        info "Fix: Add Homebrew to your shell profile by running:"
        if [ "$brew_bin" = "/opt/homebrew/bin/brew" ]; then
            echo -e "      ${YELLOW}echo 'eval \"\$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.zprofile${NC}"
        else
            echo -e "      ${YELLOW}echo 'eval \"\$(/usr/local/bin/brew shellenv)\"' >> ~/.zprofile${NC}"
        fi
        echo -e "      Then close and reopen your terminal."
        echo ""
        if ask_install "the Homebrew PATH fix"; then
            echo "eval \"\$(${brew_bin} shellenv)\"" >> "$HOME/.zprofile"
            eval "$("$brew_bin" shellenv)"
            FIXES_APPLIED=$((FIXES_APPLIED + 1))
            pass "Homebrew PATH fix applied. It will persist in new terminals."
            BREW_OK=true
        fi
    else
        # Brew is not installed at all
        fail "Homebrew is NOT installed."
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
        info "Fix: Run the following command to install Homebrew:"
        echo -e "      ${YELLOW}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
        echo ""
        if ask_install "Homebrew"; then
            info "Running the Homebrew installer... Follow any prompts that appear."
            echo ""
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            FIXES_APPLIED=$((FIXES_APPLIED + 1))
            # Try to get it in PATH now
            if ensure_brew_in_path; then
                # Also persist it
                brew_bin="$(get_brew_path)"
                if [ -n "$brew_bin" ]; then
                    echo "eval \"\$(${brew_bin} shellenv)\"" >> "$HOME/.zprofile"
                fi
                BREW_OK=true
                pass "Homebrew installed and PATH configured."
            else
                warn "Homebrew installed, but you may need to restart your terminal."
            fi
        fi
    fi
fi
echo ""

# ── 3. CLI Tools: tree, wget, git ─────────────────────────────────────────
echo -e "${BOLD}[3/4] CLI Utilities (tree, wget, git)${NC}"
echo -e "      Small command-line programs used throughout the course for"
echo -e "      viewing files, downloading content, and version control."
echo ""

BREW_PACKAGES_NEEDED=()

# tree
if command -v tree &>/dev/null; then
    pass "tree is installed. (Displays directory structures in a visual tree format.)"
else
    fail "tree is NOT installed."
    info "tree displays your project folder structure visually — helpful for debugging."
    BREW_PACKAGES_NEEDED+=("tree")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# wget
if command -v wget &>/dev/null; then
    pass "wget is installed. (Downloads files from the web via the command line.)"
else
    fail "wget is NOT installed."
    info "wget is used to download starter files and project resources."
    BREW_PACKAGES_NEEDED+=("wget")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# git
if command -v git &>/dev/null; then
    pass "git is installed. (Version control system for tracking code changes.)"
else
    fail "git is NOT installed."
    info "git tracks changes to your code and is required for project submission."
    BREW_PACKAGES_NEEDED+=("git")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

if [ ${#BREW_PACKAGES_NEEDED[@]} -gt 0 ]; then
    echo ""
    pkg_list="${BREW_PACKAGES_NEEDED[*]}"
    info "Fix: Install missing tools with Homebrew:"
    echo -e "      ${YELLOW}brew install ${pkg_list}${NC}"
    echo ""
    if $BREW_OK; then
        if ask_install "${pkg_list}"; then
            info "Installing ${pkg_list} via Homebrew..."
            brew install "${BREW_PACKAGES_NEEDED[@]}"
            FIXES_APPLIED=$((FIXES_APPLIED + 1))
            pass "Installed: ${pkg_list}"
        fi
    else
        warn "Homebrew is not available yet, so these can't be auto-installed."
        info "Please fix Homebrew first (see above), then re-run this script."
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
    # If it's not the short 'code' name, it means it's not in PATH
    if [ "$CODE_CLI" != "code" ]; then
        warn "The 'code' command is not in your shell PATH."
        info "Fix: Open VS Code, press Cmd+Shift+P, type:"
        echo -e "      ${YELLOW}Shell Command: Install 'code' command in PATH${NC}"
        echo -e "      and select it. This adds 'code' to your terminal."
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
else
    fail "'code' command not found, and VS Code was not detected."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    info "Make sure VS Code is installed in /Applications."
    info "Then open VS Code, press Cmd+Shift+P, and run:"
    echo -e "      ${YELLOW}Shell Command: Install 'code' command in PATH${NC}"
    echo ""
    if $BREW_OK; then
        info "Or install VS Code via Homebrew:"
        echo -e "      ${YELLOW}brew install --cask visual-studio-code${NC}"
        if ask_install "VS Code via Homebrew"; then
            brew install --cask visual-studio-code
            FIXES_APPLIED=$((FIXES_APPLIED + 1))
            # Re-resolve
            CODE_CLI=$(get_code_cli) || true
            if [ -n "$CODE_CLI" ]; then
                pass "VS Code installed."
            fi
        fi
    fi
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────
echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo ""
    echo -e "  ${GREEN}${BOLD}🎉 All checks passed! Your Mac is ready for EECS 280.${NC}"
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
