# EECS 280 Setup

One-click environment setup and verification for [EECS 280](https://eecs280.org) at the University of Michigan.

## Usage

1. Install this extension from the VS Code Marketplace.
2. Open the Command Palette: `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux).
3. Type **EECS 280: Verify Setup** and press Enter.
4. Follow any prompts in the terminal.

If the script finds issues, it will explain each one and offer to fix it. After fixing, re-run the command to confirm everything passes.

## What gets checked

### macOS
- Xcode Command Line Tools (C++ compiler)
- Homebrew (package manager)
- CLI tools: `tree`, `wget`, `git`
- VS Code `code` command

### Windows (WSL)
- WSL environment (user account, WSL version)
- C++ toolchain: `g++`, `gdb`, `make`
- CLI tools: `tree`, `wget`, `git`, `rsync`, `ssh`, `python3`
- VS Code `code` command

### Native Linux
- C++ toolchain: `g++`, `gdb`, `make`
- CLI tools: `tree`, `wget`, `git`, `rsync`, `ssh`, `python3`
- VS Code `code` command

## Troubleshooting

**Windows: "EECS 280 requires WSL"**
You need to install WSL and Ubuntu first, then connect VS Code to WSL. See the [WSL setup guide](https://eecs280staff.github.io/tutorials/setup_wsl.html).

**macOS: Xcode CLT installation dialog doesn't appear**
Try running `xcode-select --install` directly in Terminal.

**'code' command not found**
Open VS Code, press `Cmd+Shift+P` (or `Ctrl+Shift+P`), type "Shell Command: Install 'code' command in PATH", and run it. Then restart your terminal.

## For course staff

This extension is maintained at [github.com/kyukibug/eecs280-setup](https://github.com/kyukibug/eecs280-setup).

---

*Created by Alex Ni for EECS 280 at the University of Michigan.*