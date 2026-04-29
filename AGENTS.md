# AGENTS.md

Guidance for AI coding agents (Claude Code, etc.) working in this repository.

## What this is

A VS Code extension (`setup280`, published as `eecs280.setup280`) that verifies and fixes student dev environments for EECS 280 at the University of Michigan. Targets macOS, WSL, and native Linux; Windows-without-WSL is an explicitly-handled error state.

See `MAINTAINING.md` for the maintainer-facing publish/test guide.

## Commands

```bash
npm install                # install deps (Node 18+)
npm run compile            # tsc -p ./ → out/extension.js
npm run watch              # auto-recompile on save
npm run package            # vsce package → setup280-X.X.X.vsix
npm run publish            # vsce publish (needs marketplace creds)
```

There is no test suite or linter configured.

For interactive development, press **F5** in VS Code to launch an Extension Development Host — fastest iteration loop. Script changes (`scripts/*.sh`) don't need recompilation; TypeScript changes do.

To full-install-test a built `.vsix`:
```bash
code --install-extension setup280-X.X.X.vsix
code --uninstall-extension eecs280.setup280
```

## Architecture

The TypeScript layer is intentionally thin — it's a dispatcher. **All real verification logic lives in `scripts/verify_{macos,wsl,linux}.sh`.** When adding or changing checks, edit the bash scripts; touch `src/extension.ts` only for orchestration changes.

Three things drive behavior, two of them declarative:

1. **`package.json` `extensionDependencies`** — auto-installs `ms-vscode.cpptools` and `vadimcn.vscode-lldb` on student machines.
2. **`package.json` `contributes.configurationDefaults`** — only valid for *built-in* VS Code settings (e.g. `chat.disableAIFeatures`). VS Code's manifest validator rejects third-party-owned settings here.
3. **`src/extension.ts` `activate()`** — sets third-party settings (e.g. `lldb.showDisassembly`) programmatically via `vscode.workspace.getConfiguration()`, registers commands, and runs verification.

### `src/extension.ts` flow

`activate()` does, in order:
- Set `lldb.showDisassembly = "never"` globally (can't go in `configurationDefaults`).
- Register `eecs280.verifySetup` and `eecs280.reopenInWsl` commands.
- Create a persistent status bar item that drives a silent re-check every 10 min (`SILENT_CHECK_INTERVAL_MS`). Each tick of `updateStatusBar` first calls `maybeCreateLaunchJson` (see below), then runs the verify script silently.
- Async-detect Windows-without-WSL (see below) and override the status bar / show a notification if matched.
- Auto-run verification on first install / after update by comparing `context.globalState.get(LAST_VERIFY_VERSION_KEY)` against `context.extension.packageJSON.version`.

### Auto-generated `launch.json`

`maybeCreateLaunchJson(platform)` runs on every `updateStatusBar` tick (3 seconds after activation, then every 10 minutes). For each workspace folder it:

- Bails out if `.vscode/launch.json` already exists — student-authored configs are never overwritten.
- Calls `vscode.workspace.findFiles("**/*.{cpp,hpp,h,cc}", "**/node_modules/**", 1)` to detect a C++ project.
- If at least one match exists, writes a platform-appropriate template using `fs.writeFileSync(..., { flag: "wx" })` (the `wx` flag closes the existsSync→write race).

Two templates live as string constants at the top of `extension.ts`:

- `MACOS_LAUNCH_JSON` — CodeLLDB (`"type": "lldb"`, `"env": {}` as an object). Matches `setup_vscode_macos.md`.
- `CPPDBG_LAUNCH_JSON` — Microsoft cppdbg (`"type": "cppdbg"`, `"environment": []` as an array, `MIMode: "gdb"`, gdb pretty-printing setupCommand). Used for `wsl`, `linux`, and `windows` (the file is harmless until the student reopens in WSL). Matches `setup_vscode_wsl.md`.

**Keep these templates in sync with the EECS 280 tutorials repo** ([`eecs280staff/tutorials`](https://github.com/eecs280staff/tutorials/), specifically `docs/setup_vscode_macos.md` and `docs/setup_vscode_wsl.md`). The tutorial prose walks students through editing fields step by step (e.g., "if there's already an empty `env: {}`, replace it") and assumes the exact shape we generate — diverging silently breaks every screenshot and instruction. When the tutorial changes, update the matching template constant.

Two ways the verify script gets run:
- **`runScriptInTerminal`** — visible terminal, lets the student answer `[y/n]` install prompts. Used for the manual command and the auto-run-on-update.
- **`runScriptSilently`** — `spawn("bash", ...)` with `stdio: "ignore"`. Drives the status bar pass/fail. Relies on the verify scripts exiting `1` when `ISSUES_FOUND > 0` and `0` otherwise — **don't break that contract** when editing scripts.

### Platform detection

`detectPlatform()` returns `"macos" | "wsl" | "linux" | "windows"`. WSL is distinguished from native Linux by reading `/proc/version` for `microsoft|wsl`. `"windows"` means VS Code is running native on Windows with no WSL connection — verify scripts cannot run there.

`isWindowsWithUnusedWsl()` is a separate, more specific check: VS Code is on Windows, *not* connected to WSL (`vscode.env.remoteName !== "wsl"`), but `wsl.exe -l -q` reports at least one installed distro. This is the silent-failure mode where the student installed everything in WSL but launched VS Code as a Windows app. We surface a "Reopen in WSL" notification + status bar warning instead of running the script.

> Note: `wsl.exe -l -q` outputs UTF-16 LE — the code collects bytes and decodes explicitly. Don't switch to a default-encoding string read.

### Auto-run-on-update logic

Activation runs verification when `lastVerifyVersion !== currentVersion`. The stored version is updated *after* launching the terminal so a crash during launch leaves the next activation able to retry. Bumping the version in `package.json` therefore re-triggers the visible verification for every existing student on their next VS Code restart.

### Bundled scripts

The verify scripts are shipped inside the `.vsix` (not in `.vscodeignore`), so they work offline. There is no remote-update mechanism — to ship a script change, bump the version and republish.

## Adding a new check

Edit the relevant `scripts/verify_*.sh` following the existing pattern: `pass`/`fail` helpers, increment `ISSUES_FOUND`, append to the install-list array. Update the `[N/M]` section header counts. Mirror the change across all three scripts when the check is platform-shared.

## Adding a new command

1. Add to `package.json` → `contributes.commands` (use the `EECS 280:` title prefix and `category: "EECS 280"`).
2. Register in `activate()` with `vscode.commands.registerCommand` and push the disposable into `context.subscriptions`.

## Settings precedence rules

- Built-in VS Code setting → `package.json` `configurationDefaults`.
- Setting owned by another extension → `vscode.workspace.getConfiguration(...).update(...)` in `activate()`. The manifest validator will reject these in `configurationDefaults`.
