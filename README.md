# EECS 280 Setup

One-click environment setup and verification for [EECS 280](https://eecs280.org) at the University of Michigan.

## Quick Start

Install the EECS 280 Course Setup extension from the [Marketplace](https://marketplace.visualstudio.com/items?itemName=eecs280.setup280)

## Summary

This extension automatically configures VS Code and verifies your EECS 280 C++ development environment.  The end result should match what you'd get by following the EECS 280 [Setup tutorials](https://eecs280staff.github.io/tutorials/).

| | macOS | WSL | Linux |
|---|:---:|:---:|:---:|
| Installs [C/C++](https://marketplace.visualstudio.com/items?itemName=ms-vscode.cpptools) and [CodeLLDB](https://marketplace.visualstudio.com/items?itemName=vadimcn.vscode-lldb) extensions | ✓ | ✓ | ✓ |
| Installs [WSL](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl) extension | — | ✓ | — |
| Disables AI/Copilot features (per GenAI [policy](https://eecs280.org/syllabus.html#generative-ai-policy)) | ✓ | ✓ | ✓ |
| Generates `.vscode/launch.json` if missing | ✓ (CodeLLDB) | ✓ (cppdbg/gdb) | ✓ (cppdbg/gdb) |
| Checks Xcode Command Line Tools | ✓ | — | — |
| Checks Homebrew | ✓ | — | — |
| Checks WSL version and user | — | ✓ | — |
| Checks `g++`, `gdb`, `make` | — | ✓ | ✓ |
| Checks `tree`, `wget`, `git` | ✓ | ✓ | ✓ |
| Checks `rsync`, `ssh`, `python3` | — | ✓ | ✓ |
| Checks VS Code `code` command | ✓ | ✓ | ✓ |

The verification script will explain any issues it finds and offer to fix them. The default `launch.json` is only written when the open folder contains C++ files (`.cpp`, `.hpp`, `.h`, `.cc`); an existing one is never overwritten.

## Re-running verification

The verification script re-runs automatically on first install and after each extension update, plus a silent re-check every 10 minutes that keeps the **EECS 280** status bar indicator (✓ / error / warning) up to date.  To re-check your environment manually:

1. Open the Command Palette:
   - macOS: `Cmd+Shift+P`
   - Windows/Linux: `Ctrl+Shift+P`
2. Type **EECS 280: Verify Setup** and press Enter.
3. Follow any prompts in the terminal.

## Troubleshooting

**Windows: "EECS 280 requires WSL"**
You need to install WSL and Ubuntu first, then connect VS Code to WSL. See the [WSL setup guide](https://eecs280staff.github.io/tutorials/setup_wsl.html).

**Windows: "Not in WSL" status bar warning**
You have WSL installed, but VS Code is running as a Windows app. The extension shows a notification on activation — click **Open in WSL** (no folder open) or **Reopen in WSL** (folder open) to connect. Clicking the **EECS 280: Not in WSL** status bar item does the same thing. Once inside WSL, verification runs automatically.

**macOS: Xcode CLT installation dialog doesn't appear**
Try running `xcode-select --install` directly in Terminal.

**'code' command not found**
Open VS Code, press `Cmd+Shift+P` (or `Ctrl+Shift+P`), type "Shell Command: Install 'code' command in PATH", and run it. Then restart your terminal.

**Copilot/AI features stopped working after install**
This is intentional — the extension disables AI assistants per the course's GenAI policy. Contact course staff if you have questions.

## Contributing and maintaining

See [MAINTAINING.md](MAINTAINING.md) for the maintainer guide (release process, testing, and contribution workflow), and [AGENTS.md](AGENTS.md) for guidance on AI coding agents working in this repo.

Related documentation that references this extension (update alongside changes here):

- [EECS 280 tutorials repo](https://github.com/eecs280staff/tutorials/)
- [macOS VS Code setup guide](https://github.com/eecs280staff/tutorials/blob/main/docs/setup_vscode_macos.md)
- [WSL VS Code setup guide](https://github.com/eecs280staff/tutorials/blob/main/docs/setup_vscode_wsl.md)

To embed an install link in HTML (e.g., a course web page), use `vscode:extension/eecs280.setup280` — clicking it opens VS Code and installs the extension with one click.


## Acknowledgements

The original extension was written by Alex Ni in 2026.
