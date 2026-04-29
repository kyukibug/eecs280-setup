# EECS 280 Setup

One-click VS Code environment setup and verification for [EECS 280](https://eecs280.org) at the University of Michigan.

## Quick Start

Click to [install in VS Code](vscode:extension/eecs280.setup280), opens VS Code and installs the extension in one click.

If the link doesn't open VS Code, install from the [Marketplace](https://marketplace.visualstudio.com/items?itemName=eecs280.setup280) instead.

## What this extension does

When you install this extension, it automatically:

- **Installs required VS Code extensions:** [C/C++](https://marketplace.visualstudio.com/items?itemName=ms-vscode.cpptools) and [CodeLLDB](https://marketplace.visualstudio.com/items?itemName=vadimcn.vscode-lldb) for C++ editing and debugging.
- **Applies course-default settings:** disables AI/Copilot features (per the course's GenAI policy) and configures LLDB for the course's debugging workflow.
- **Runs verification automatically:** on first install and after extension updates, a terminal opens and checks that your development environment is set up correctly. The script will explain any issues it finds and offer to fix them.

It also provides an **EECS 280: Verify Setup** command you can run manually any time you want to re-check your environment.

## Re-running verification

Verification runs automatically on first install and after updates (see above). To re-check manually any time:

1. Open the Command Palette:
   - macOS: `Cmd+Shift+P`
   - Windows/Linux: `Ctrl+Shift+P`
2. Type **EECS 280: Verify Setup** and press Enter.
3. Follow any prompts in the terminal.

## What gets checked

| Check | macOS | WSL | Linux |
|---|:---:|:---:|:---:|
| Xcode Command Line Tools (C++ compiler) | ✓ | — | — |
| Homebrew (package manager) | ✓ | — | — |
| WSL environment (user, version) | — | ✓ | — |
| `g++`, `gdb`, `make` | — | ✓ | ✓ |
| `tree`, `wget`, `git` | ✓ | ✓ | ✓ |
| `rsync`, `ssh`, `python3` | — | ✓ | ✓ |
| VS Code `code` command | ✓ | ✓ | ✓ |

## Troubleshooting

**Windows: "EECS 280 requires WSL"**
You need to install WSL and Ubuntu first, then connect VS Code to WSL. See the [WSL setup guide](https://eecs280staff.github.io/tutorials/setup_wsl.html).

**macOS: Xcode CLT installation dialog doesn't appear**
Try running `xcode-select --install` directly in Terminal.

**'code' command not found**
Open VS Code, press `Cmd+Shift+P` (or `Ctrl+Shift+P`), type "Shell Command: Install 'code' command in PATH", and run it. Then restart your terminal.

**Copilot/AI features stopped working after install**
This is intentional — the extension disables AI assistants per the course's GenAI policy. Contact course staff if you have questions.

## For course staff

This extension is maintained at [github.com/eecs280staff/vscode-setup280](https://github.com/eecs280staff/vscode-setup280). See [MAINTAINING.md](MAINTAINING.md) for the maintainer guide (release process, testing, and contribution workflow), and [AGENTS.md](AGENTS.md) for guidance on AI coding agents working in this repo.

Related documentation that references this extension (update alongside changes here):

- [EECS 280 tutorials repo](https://github.com/eecs280staff/tutorials/)
- [macOS VS Code setup guide](https://github.com/eecs280staff/tutorials/blob/main/docs/setup_vscode_macos.md)
- [WSL VS Code setup guide](https://github.com/eecs280staff/tutorials/blob/main/docs/setup_vscode_wsl.md)

---

*Created by Alex Ni for EECS 280 at the University of Michigan.*
