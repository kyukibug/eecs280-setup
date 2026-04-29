import * as vscode from "vscode";
import * as path from "path";
import * as fs from "fs";
import { spawn } from "child_process";

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
//      integrated terminal. The verification also runs automatically on
//      first install and after extension updates.
//   4. Maintains a persistent status bar item showing setup pass/fail at a
//      glance. Re-checks silently in the background every few minutes so
//      students who ignore a failed verification still see they aren't OK.
//
// Architecture:
//   - The bash scripts in scripts/ do ALL the heavy lifting (checking tools,
//     offering to install, colored output, etc.). This TypeScript code just
//     figures out which script to run and launches it.
//   - Scripts are bundled with the extension (not fetched remotely), so they
//     work offline after install. To update scripts, bump the extension version
//     and republish.
//   - The verify scripts exit with code 1 when ISSUES_FOUND > 0 (and 0 when
//     everything passes), which is how the silent background check determines
//     pass/fail.
//
// Maintainer notes:
//   - To add a new check, edit the bash script(s) in scripts/.
//   - To add a new command, add it to package.json "contributes.commands" and
//     register it in the activate() function below.
//   - To change default settings, edit package.json "configurationDefaults".
//   - To add a new required extension, add it to "extensionDependencies".
// =============================================================================

/** globalState key tracking the extension version that last triggered an
 *  auto-run of verification. Used to detect first install (undefined) and
 *  updates (stored version differs from current). */
const LAST_VERIFY_VERSION_KEY = "lastVerifyVersion";

/** workspaceState key tracking whether the student dismissed the "not
 *  connected to WSL" notification permanently for this folder. */
const WSL_NOTIFICATION_DISMISSED_KEY = "wslNotificationDismissed";

/** How often to re-run the silent verification check, in milliseconds.
 *  10 minutes balances staying current with not spawning bash processes
 *  too aggressively. */
const SILENT_CHECK_INTERVAL_MS = 10 * 60 * 1000;

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
 * Detects whether the student is running Windows VS Code with WSL installed
 * but NOT connected to it.
 *
 * This is a silent failure mode: the student set up WSL, installed the
 * toolchain inside it, but launched VS Code as a regular Windows app. From
 * VS Code's perspective everything looks like Windows-native — no compiler,
 * no debugger, no bash. The student gets confusing errors and has no idea
 * why.
 *
 * The fix is one click: VS Code's "Reopen Folder in WSL" command. We just
 * need to detect the state and surface the action.
 *
 * Detection criteria (all must be true):
 *   - process.platform === "win32" (running on Windows side, not Linux)
 *   - vscode.env.remoteName !== "wsl" (not connected to WSL remote — this
 *     is how VS Code itself reports the connection state)
 *   - `wsl.exe -l -q` returns at least one distro (WSL is installed and has
 *     at least one distro registered, so the fix is actually viable)
 *
 * Returns a Promise so we can await the wsl.exe spawn without blocking
 * activation.
 */
function isWindowsWithUnusedWsl(): Promise<boolean> {
  if (process.platform !== "win32") {
    return Promise.resolve(false);
  }
  if (vscode.env.remoteName === "wsl") {
    return Promise.resolve(false);
  }

  // Spawn `wsl.exe -l -q` to check if any distros are installed.
  // The -q flag gives us just the distro names, no headers.
  // Output is UTF-16 LE encoded by default, so we collect as Buffer and
  // decode explicitly rather than relying on stream default encoding.
  return new Promise((resolve) => {
    const child = spawn("wsl.exe", ["-l", "-q"], { stdio: ["ignore", "pipe", "ignore"] });
    const chunks: Buffer[] = [];

    child.stdout.on("data", (chunk: Buffer) => {
      chunks.push(chunk);
    });

    child.on("exit", (code) => {
      if (code !== 0) {
        // wsl.exe exited with an error — most likely "no distros installed"
        // or WSL feature not enabled. Either way, this isn't the state we
        // want to act on (we want WSL installed AND a distro present).
        resolve(false);
        return;
      }

      // Decode UTF-16 LE, strip nulls and CR, check for any non-empty line.
      const decoded = Buffer.concat(chunks)
        .toString("utf16le")
        .replace(/\0/g, "")
        .replace(/\r/g, "");
      const hasDistro = decoded.split("\n").some((line) => line.trim().length > 0);
      resolve(hasDistro);
    });

    child.on("error", () => {
      // wsl.exe doesn't exist on PATH at all — WSL feature not installed.
      resolve(false);
    });
  });
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

// Default launch.json templates, one per debugger.
//
// IMPORTANT: keep these in sync with the EECS 280 tutorials repo
// (eecs280staff/tutorials → docs/setup_vscode_macos.md and
// docs/setup_vscode_wsl.md). The tutorial walks students through editing
// the launch.json fields step by step, and the prose ("If there's already
// an empty `env: {}`, replace it...") assumes the exact shape generated
// here. When the tutorial changes, update the matching template below.
//
// Why two templates: macOS uses the CodeLLDB extension (vadimcn.vscode-lldb,
// "type": "lldb", env as an object) and WSL/Linux use Microsoft's C/C++
// extension (ms-vscode.cpptools, "type": "cppdbg", environment as an
// array, plus MIMode and gdb pretty-printing setupCommand). Both extensions
// are listed in package.json extensionDependencies, so either type
// resolves on every platform — but the tutorials prescribe one per OS,
// and we match that.

/**
 * Default launch.json for macOS (CodeLLDB).
 *
 * Mirrors the post-edit shape from setup_vscode_macos.md, including the
 * empty `"env": {}` so the ASAN sanitizer subsection's "if there's already
 * an empty env, replace it" instructions work verbatim.
 */
const MACOS_LAUNCH_JSON = `{
  // Generated by the EECS 280 Setup extension. Update "program" below
  // if your compiled executable has a different name than "main.exe".
  // See https://eecs280staff.github.io/tutorials/setup_vscode_macos.html
  "version": "0.2.0",
  "configurations": [
    {
      "type": "lldb",
      "request": "launch",
      "name": "Debug",
      "program": "\${workspaceFolder}/main.exe",
      "args": [],
      "cwd": "\${workspaceFolder}",
      "env": {}
    }
  ]
}
`;

/**
 * Default launch.json for WSL and native Linux (Microsoft cppdbg / gdb).
 *
 * Mirrors the "C/C++ (gdb) Launch" template from setup_vscode_wsl.md,
 * including the empty `"environment": []` so the sanitizer subsection's
 * "if there's already an empty environment, replace it" instructions
 * work verbatim, plus the standard pretty-printing setupCommand.
 */
const CPPDBG_LAUNCH_JSON = `{
  // Generated by the EECS 280 Setup extension. Update "program" below
  // if your compiled executable has a different name than "main.exe".
  // See https://eecs280staff.github.io/tutorials/setup_vscode_wsl.html
  "version": "0.2.0",
  "configurations": [
    {
      "type": "cppdbg",
      "request": "launch",
      "name": "Debug",
      "program": "\${workspaceFolder}/main.exe",
      "args": [],
      "stopAtEntry": false,
      "cwd": "\${workspaceFolder}",
      "environment": [],
      "externalConsole": false,
      "MIMode": "gdb",
      "setupCommands": [
        {
          "description": "Enable pretty-printing for gdb",
          "text": "-enable-pretty-printing",
          "ignoreFailures": true
        }
      ]
    }
  ]
}
`;

/**
 * Picks the right launch.json template for a platform.
 *
 * On Windows-without-WSL we still write the cppdbg variant: the file is
 * harmless until the student reopens the folder in WSL, at which point
 * it's already correct.
 */
function getDefaultLaunchJson(
  platform: "macos" | "wsl" | "linux" | "windows"
): string {
  if (platform === "macos") {
    return MACOS_LAUNCH_JSON;
  }
  return CPPDBG_LAUNCH_JSON;
}

/**
 * If the workspace looks like a C++ project (has any .cpp/.hpp/.h/.cc
 * file) and has no .vscode/launch.json, write a default debugger launch
 * config matching the platform's tutorial (CodeLLDB on macOS, cppdbg on
 * WSL/Linux) so the student can hit F5 to debug after `make main.exe`.
 *
 * Bails out silently if launch.json already exists — we never overwrite a
 * student-authored config. Safe to call repeatedly from the periodic
 * silent check; the 10-minute cadence means students who add C++ files
 * after opening the folder still get a launch.json on the next tick
 * without needing a file watcher.
 */
async function maybeCreateLaunchJson(
  platform: "macos" | "wsl" | "linux" | "windows"
): Promise<void> {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders) {
    return;
  }

  const template = getDefaultLaunchJson(platform);

  for (const folder of folders) {
    const launchPath = path.join(folder.uri.fsPath, ".vscode", "launch.json");
    if (fs.existsSync(launchPath)) {
      continue;
    }

    // Scope the scan to this folder and stop after the first hit — we
    // only need to know whether *any* C++ source/header exists.
    const pattern = new vscode.RelativePattern(folder, "**/*.{cpp,hpp,h,cc}");
    const matches = await vscode.workspace.findFiles(
      pattern,
      "**/node_modules/**",
      1
    );
    if (matches.length === 0) {
      continue;
    }

    try {
      fs.mkdirSync(path.dirname(launchPath), { recursive: true });
      // "wx" fails if the file already exists, closing the small race
      // window between existsSync above and the write here.
      fs.writeFileSync(launchPath, template, { flag: "wx" });
    } catch {
      // Read-only filesystem, permissions, or a concurrent writer beat
      // us to it. Nothing actionable from the status bar path — leave
      // whatever state exists and try again on the next tick.
    }
  }
}

/**
 * Maps a platform to its verify script filename. Returns null for platforms
 * that don't have a script (windows-without-WSL).
 */
function getScriptNameForPlatform(
  platform: "macos" | "wsl" | "linux" | "windows"
): string | null {
  switch (platform) {
    case "macos":
      return "verify_macos.sh";
    case "wsl":
      return "verify_wsl.sh";
    case "linux":
      return "verify_linux.sh";
    case "windows":
      return null;
  }
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
 * Runs a bash script silently in the background and resolves to true if
 * it exited cleanly (code 0), false otherwise.
 *
 * Used by the status bar to passively check setup status without showing
 * a terminal. The verify scripts exit 1 when ISSUES_FOUND > 0, so the
 * exit code is a reliable pass/fail signal.
 *
 * stdio is set to "ignore" so the script's interactive [y/n] prompts get
 * an immediate EOF on stdin. The scripts don't use `set -e`, so they
 * continue past the failed reads and still produce a meaningful exit code.
 */
function runScriptSilently(scriptPath: string): Promise<boolean> {
  return new Promise((resolve) => {
    const child = spawn("bash", ["-l", scriptPath], {
      stdio: "ignore",
    });
    child.on("exit", (code) => {
      resolve(code === 0);
    });
    child.on("error", () => {
      // Couldn't spawn bash, or some other process error. Treat as fail
      // so the status bar shows something is wrong rather than falsely OK.
      resolve(false);
    });
  });
}

/**
 * Runs the verification script appropriate for the current platform.
 *
 * Shared between the manual "EECS 280: Verify Setup" command and the
 * automatic run on first install / after updates.
 *
 * The `isAutoRun` flag controls behavior for the Windows (non-WSL) case:
 *   - Manual invocation: shows a warning popup with a link to the WSL
 *     setup guide, since the student explicitly asked us to verify and
 *     deserves actionable feedback.
 *   - Auto-run: silently no-ops, so students who installed the extension
 *     on a Windows VS Code they use for other projects don't get an
 *     unprompted warning popup.
 */
function runVerificationForPlatform(
  context: vscode.ExtensionContext,
  isAutoRun: boolean
): void {
  const platform = detectPlatform();
  const scriptName = getScriptNameForPlatform(platform);

  if (scriptName !== null) {
    runScriptInTerminal(getScriptPath(context, scriptName));
    return;
  }

  // Windows-without-WSL case
  if (isAutoRun) {
    // Don't surface an unprompted warning on auto-run.
    return;
  }
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
}

/**
 * Sets the status bar item to the "Not in WSL" warning state.
 *
 * Used when we detect Windows VS Code with WSL installed but not connected.
 * The verify scripts can't run in this state (no bash), so we override the
 * normal pass/fail display with a more actionable warning.
 *
 * Clicking the status bar in this state triggers a folder reopen in WSL.
 */
function setStatusBarToWslWarning(statusBarItem: vscode.StatusBarItem): void {
  statusBarItem.text = "$(warning) EECS 280: Not in WSL";
  statusBarItem.backgroundColor = new vscode.ThemeColor(
    "statusBarItem.warningBackground"
  );
  statusBarItem.tooltip =
    "VS Code is running on Windows, not connected to WSL. Click to reopen this folder in WSL.";
  statusBarItem.command = "eecs280.reopenInWsl";
}

/**
 * Shows the "not connected to WSL" notification with action buttons.
 *
 * Respects the per-workspace dismissal flag — if the student has clicked
 * "Don't show again" in this folder before, this is a no-op.
 */
async function maybeShowWslNotification(
  context: vscode.ExtensionContext
): Promise<void> {
  const dismissed = context.workspaceState.get<boolean>(
    WSL_NOTIFICATION_DISMISSED_KEY,
    false
  );
  if (dismissed) {
    return;
  }

  const reopenLabel = "Reopen in WSL";
  const dontShowLabel = "Don't show again";

  const selection = await vscode.window.showWarningMessage(
    "EECS 280: VS Code is running on Windows, but EECS 280 work should be done inside WSL. " +
      "Reopen this folder in WSL to use the toolchain you've installed.",
    reopenLabel,
    dontShowLabel
  );

  if (selection === reopenLabel) {
    // remote-wsl.reopenInWSL is the command that powers the blue "><"
    // button's "Reopen Folder in WSL" action. It reopens the current
    // folder in a WSL-connected window.
    await vscode.commands.executeCommand("remote-wsl.reopenInWSL");
  } else if (selection === dontShowLabel) {
    await context.workspaceState.update(WSL_NOTIFICATION_DISMISSED_KEY, true);
  }
  // Closing the X (selection === undefined) is intentionally just a session
  // dismissal — the notification will reappear on next activation.
}

/**
 * Updates the status bar item by silently running the verify script and
 * inspecting its exit code. Sets a green check on pass, a red error on
 * fail, and a yellow warning on Windows-without-WSL (where there's no
 * script to run).
 *
 * Idempotent and safe to call repeatedly — that's the whole point.
 */
async function updateStatusBar(
  context: vscode.ExtensionContext,
  statusBarItem: vscode.StatusBarItem
): Promise<void> {
  const platform = detectPlatform();

  // Auto-generate .vscode/launch.json for C++ projects that don't have
  // one yet so students can debug with F5 after a small edit. No-ops if
  // launch.json already exists or the workspace has no C++ files. The
  // template differs by platform — see getDefaultLaunchJson.
  await maybeCreateLaunchJson(platform);

  if (platform === "windows") {
    statusBarItem.text = "$(warning) EECS 280: WSL Required";
    statusBarItem.backgroundColor = new vscode.ThemeColor(
      "statusBarItem.warningBackground"
    );
    statusBarItem.tooltip =
      "EECS 280 requires WSL. Click for setup instructions.";
    statusBarItem.command = "eecs280.verifySetup";
    return;
  }

  const scriptName = getScriptNameForPlatform(platform);
  if (scriptName === null) {
    // Defensive: shouldn't happen given the platform check above, but
    // satisfies the type checker and avoids a runtime crash.
    return;
  }

  // Show a brief "verifying" state so the student knows something is
  // happening if they happen to be looking. The spinner stops the moment
  // the promise below resolves.
  statusBarItem.text = "$(sync~spin) EECS 280: Verifying...";
  statusBarItem.backgroundColor = undefined;
  statusBarItem.tooltip = "Checking your EECS 280 environment...";
  statusBarItem.command = "eecs280.verifySetup";

  const scriptPath = getScriptPath(context, scriptName);
  const passed = await runScriptSilently(scriptPath);

  if (passed) {
    statusBarItem.text = "$(check) EECS 280: Setup OK";
    statusBarItem.backgroundColor = undefined;
    statusBarItem.tooltip =
      "Your EECS 280 environment looks good. Click to re-verify.";
  } else {
    statusBarItem.text = "$(error) EECS 280: Setup Incomplete";
    statusBarItem.backgroundColor = new vscode.ThemeColor(
      "statusBarItem.errorBackground"
    );
    statusBarItem.tooltip =
      "Your EECS 280 environment has issues. Click to see what's missing.";
  }
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
      runVerificationForPlatform(context, false);
    }
  );
  context.subscriptions.push(verifyCommand);

  // Register the "Reopen in WSL" command, used by both the WSL warning
  // notification action button and the status bar in the not-in-WSL state.
  // We wrap the underlying remote-wsl.reopenInWSL command so we have a
  // single, stable command id to bind to the status bar.
  const reopenInWslCommand = vscode.commands.registerCommand(
    "eecs280.reopenInWsl",
    () => vscode.commands.executeCommand("remote-wsl.reopenInWSL")
  );
  context.subscriptions.push(reopenInWslCommand);

  // Create the persistent status bar item.
  // Left-aligned with priority 100 — higher priority means further left.
  // Clicking it re-runs the visible verification command (the command may
  // be reassigned to "reopen in WSL" later if we detect that state).
  const statusBarItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Left,
    100
  );
  statusBarItem.command = "eecs280.verifySetup";
  statusBarItem.text = "$(sync~spin) EECS 280: Verifying...";
  statusBarItem.tooltip = "Checking your EECS 280 environment...";
  statusBarItem.show();
  context.subscriptions.push(statusBarItem);

  // Detect Windows-with-unused-WSL state BEFORE doing anything else.
  //
  // This is a state where the student has WSL installed but launched VS Code
  // as a regular Windows app instead of connecting to WSL. The verify scripts
  // can't run (no bash), and the auto-run-on-update logic would no-op
  // unhelpfully. Instead, we want to:
  //   - Show a notification offering to reopen in WSL
  //   - Set the status bar to a "Not in WSL" warning
  //   - Skip both the silent verify and the visible auto-run
  //
  // We kick off the detection asynchronously and let the rest of activation
  // proceed assuming the normal flow. If detection comes back true, we
  // override the status bar and short-circuit. If detection comes back false,
  // we fall through to the normal silent-verify scheduling below.
  //
  // The flag below lets us cancel the scheduled silent verify if the WSL
  // check resolves true after the timer was already set.
  let normalFlowCancelled = false;

  void isWindowsWithUnusedWsl().then((isUnusedWsl) => {
    if (!isUnusedWsl) {
      return;
    }
    normalFlowCancelled = true;
    setStatusBarToWslWarning(statusBarItem);
    void maybeShowWslNotification(context);
  });

  // Auto-run verification on first install and after extension updates.
  //
  // We compare the version stored in globalState to the extension's current
  // version. If they differ (including the undefined-vs-version case on
  // first install), we run the verification script and update the stored
  // version so subsequent activations of this same version skip the auto-run.
  //
  // We update globalState AFTER launching the terminal so that if anything
  // throws during launch, the next activation will retry rather than silently
  // marking this version as done.
  //
  // Note: on Windows-with-unused-WSL, runVerificationForPlatform with
  // isAutoRun=true is already a no-op (the platform is "windows" and auto-run
  // suppresses the warning), so we don't need to gate this on the WSL check.
  const currentVersion = context.extension.packageJSON.version;
  const lastRunVersion = context.globalState.get<string>(
    LAST_VERIFY_VERSION_KEY
  );
  const isFirstRunOrUpdate = lastRunVersion !== currentVersion;

  if (isFirstRunOrUpdate) {
    runVerificationForPlatform(context, true);

    // Only surface the "heads up" notification on platforms where we actually
    // launched a terminal. On Windows the auto-run is a no-op, so the message
    // would be misleading.
    if (detectPlatform() !== "windows") {
      vscode.window.showInformationMessage(
        "EECS 280 Setup is verifying your environment in the terminal below."
      );
    }

    context.globalState.update(LAST_VERIFY_VERSION_KEY, currentVersion);
  }

  // Kick off the silent background check that drives the status bar.
  //
  // We wait 3 seconds before the first check so VS Code has fully settled
  // (extensions loaded, terminals available). On first install / update,
  // this runs concurrently with the visible auto-run terminal — that's
  // fine, the verify scripts only do read-only checks and the duplicated
  // work is negligible. The benefit is the status bar resolves to a real
  // pass/fail state immediately rather than sitting in a placeholder until
  // the periodic interval fires.
  //
  // If the WSL detection resolved true in the meantime, we skip the silent
  // verify entirely — running bash on Windows-without-connection would just
  // fail and overwrite the actionable "Not in WSL" warning with a generic
  // "Setup Incomplete".
  setTimeout(() => {
    if (normalFlowCancelled) {
      return;
    }
    void updateStatusBar(context, statusBarItem);
  }, 3000);

  // Re-run the silent check periodically so a student who ignored a failed
  // verification still sees the red status bar update / clear when they fix
  // (or don't fix) their environment.
  const intervalHandle = setInterval(() => {
    if (normalFlowCancelled) {
      return;
    }
    void updateStatusBar(context, statusBarItem);
  }, SILENT_CHECK_INTERVAL_MS);
  context.subscriptions.push({
    dispose: () => clearInterval(intervalHandle),
  });

  // Refresh the status bar promptly after a verify run in the visible
  // terminal — otherwise a student who fixes issues from the verify prompts
  // would see a stale status bar until the next periodic silent check fires
  // (up to SILENT_CHECK_INTERVAL_MS later).
  //
  // Two complementary triggers:
  //   - onDidEndTerminalShellExecution: fires when the verify command's
  //     prompt returns. Requires shell integration (VS Code 1.93+) that bash
  //     gets automatically in modern VS Code. This catches the case where the
  //     student fixes issues and leaves the terminal open.
  //   - onDidCloseTerminal: fallback for environments where shell
  //     integration isn't active. Catches the common case where the student
  //     closes the terminal after seeing the verify finish.
if (typeof vscode.window.onDidEndTerminalShellExecution === "function") {
  context.subscriptions.push(
    vscode.window.onDidEndTerminalShellExecution((event) => {
      if (normalFlowCancelled) {
        return;
      }
      if (event.terminal.name !== "EECS 280 Setup") {
        return;
      }
      // Filter to the verify command itself so unrelated commands the
      // student might type in the same terminal don't trigger refreshes.
      if (!event.execution.commandLine.value.includes("verify_")) {
        return;
      }
      void updateStatusBar(context, statusBarItem);
    })
  );
}

context.subscriptions.push(
  vscode.window.onDidCloseTerminal((terminal) => {
    if (normalFlowCancelled) {
      return;
    }
    if (terminal.name === "EECS 280 Setup") {
      void updateStatusBar(context, statusBarItem);
    }
  })
);
}

/**
 * Extension deactivation — called when the extension is unloaded.
 * Nothing to clean up for this extension.
 */
export function deactivate(): void {
  // No cleanup needed
}