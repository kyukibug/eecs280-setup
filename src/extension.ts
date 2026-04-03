import * as vscode from "vscode";
import * as path from "path";
import * as fs from "fs";

// =============================================================================
// EECS 280 Setup Extension — Main Entry Point
// =============================================================================
//
// This extension does three things:
//   1. Automatically installs required extensions (C/C++, CodeLLDB, WSL) via
//      extensionDependencies in package.json — no code needed here.
//   2. Applies course-default settings (disable AI features, LLDB config) via
//      configurationDefaults in package.json — no code needed here either.
//   3. Registers the "EECS 280: Verify Setup" command, which detects the
//      student's OS and runs the appropriate verification script in the
//      integrated terminal.
//
// Architecture:
//   - The bash scripts in scripts/ do ALL the heavy lifting (checking tools,
//     offering to install, colored output, etc.). This TypeScript code just
//     figures out which script to run and launches it.
//   - Scripts are bundled with the extension (not fetched remotely), so they
//     work offline after install. To update scripts, bump the extension version
//     and republish.
//
// Maintainer notes:
//   - To add a new check, edit the bash script(s) in scripts/.
//   - To add a new command, add it to package.json "contributes.commands" and
//     register it in the activate() function below.
//   - To change default settings, edit package.json "configurationDefaults".
//   - To add a new required extension, add it to "extensionDependencies".
// =============================================================================

/**
 * Detects the current platform from VS Code's perspective.
 *
 * Returns one of:
 *   - "macos"   — running on macOS (Darwin)
 *   - "wsl"     — running inside WSL (VS Code remote into Linux on Windows)
 *   - "linux"   — running on native Linux (not WSL)
 *   - "windows" — running on Windows without WSL (unsupported for EECS 280)
 */
function detectPlatform(): "macos" | "wsl" | "linux" | "windows" {
  const platform = process.platform;

  if (platform === "darwin") {
    return "macos";
  }

  if (platform === "linux") {
    // Check if we're inside WSL by looking for the WSL-specific /proc entry.
    // This file exists in WSL 1 and WSL 2 and contains "microsoft" or "WSL".
    try {
      const procVersion = fs.readFileSync("/proc/version", "utf-8");
      if (/microsoft|wsl/i.test(procVersion)) {
        return "wsl";
      }
    } catch {
      // If we can't read /proc/version, assume native Linux
    }
    return "linux";
  }

  // win32 — student opened VS Code on Windows without connecting to WSL
  return "windows";
}

/**
 * Returns the absolute path to a script bundled with the extension.
 *
 * Scripts live in the scripts/ directory at the extension root. When the
 * extension is packaged (.vsix), these files are included because they're
 * not in .vscodeignore.
 */
function getScriptPath(
  context: vscode.ExtensionContext,
  scriptName: string
): string {
  return path.join(context.extensionPath, "scripts", scriptName);
}

/**
 * Runs a bash script in the VS Code integrated terminal.
 *
 * Creates a new terminal named "EECS 280 Setup", sends the bash command,
 * and focuses the terminal so the student can see the output and interact
 * with any [y/n] prompts.
 */
function runScriptInTerminal(scriptPath: string): void {
  // Dispose any existing EECS 280 terminal to avoid confusion
  const existingTerminal = vscode.window.terminals.find(
    (t) => t.name === "EECS 280 Setup"
  );
  if (existingTerminal) {
    existingTerminal.dispose();
  }

  const terminal = vscode.window.createTerminal({
    name: "EECS 280 Setup",
    // Use bash explicitly — students on macOS default to zsh, but our
    // scripts have #!/usr/bin/env bash and need bash features.
    shellPath: "/bin/bash",
    shellArgs: ["-l"], // Login shell so PATH includes Homebrew, etc.
  });

  terminal.show(true); // true = preserve focus on terminal

  // Run the script via bash. Using sendText so the script can read user
  // input (y/n prompts) from stdin — child_process.exec wouldn't allow this.
  terminal.sendText(`bash "${scriptPath}"`, true);
}

/**
 * Extension activation — called once when the extension is first loaded.
 *
 * This happens when:
 *   - The user runs the "EECS 280: Verify Setup" command
 *   - VS Code starts and the extension is installed (due to empty
 *     activationEvents in package.json, which means activate on startup)
 */
export function activate(context: vscode.ExtensionContext): void {
  // Apply LLDB settings programmatically.
  // We can't use configurationDefaults in package.json for settings owned
  // by other extensions (VS Code validates the manifest and rejects them).
  // Instead, we set it here on activation via the workspace configuration API.
  const lldbConfig = vscode.workspace.getConfiguration("lldb");
  if (lldbConfig.get("showDisassembly") !== "never") {
    lldbConfig.update("showDisassembly", "never", vscode.ConfigurationTarget.Global);
  }

  // Register the main "Verify Setup" command
  const verifyCommand = vscode.commands.registerCommand(
    "eecs280.verifySetup",
    () => {
      const platform = detectPlatform();

      switch (platform) {
        case "macos": {
          const scriptPath = getScriptPath(context, "verify-macos.sh");
          runScriptInTerminal(scriptPath);
          break;
        }

        case "wsl": {
          const scriptPath = getScriptPath(context, "verify-wsl.sh");
          runScriptInTerminal(scriptPath);
          break;
        }

        case "linux": {
          const scriptPath = getScriptPath(context, "verify-linux.sh");
          runScriptInTerminal(scriptPath);
          break;
        }

        case "windows": {
          // Student is on Windows but hasn't connected VS Code to WSL.
          // Show a helpful message explaining what to do.
          vscode.window
            .showWarningMessage(
              "EECS 280 requires WSL (Windows Subsystem for Linux). " +
                "Please install WSL and Ubuntu, then connect VS Code to WSL " +
                'by clicking the blue "><" icon in the bottom-left corner ' +
                'and selecting "Connect to WSL".',
              "Open WSL Setup Guide"
            )
            .then((selection) => {
              if (selection === "Open WSL Setup Guide") {
                vscode.env.openExternal(
                  vscode.Uri.parse(
                    "https://eecs280staff.github.io/tutorials/setup_wsl.html"
                  )
                );
              }
            });
          break;
        }
      }
    }
  );

  context.subscriptions.push(verifyCommand);
}

/**
 * Extension deactivation — called when the extension is unloaded.
 * Nothing to clean up for this extension.
 */
export function deactivate(): void {
  // No cleanup needed
}