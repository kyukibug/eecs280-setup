# Maintaining the EECS 280 Setup Extension

Guide for the TA maintaining this extension. Covers local development,
making changes, and publishing updates to the VS Code Marketplace.

## Prerequisites

- **Node.js** v18+ (check: `node --version`) — https://nodejs.org
- **npm** (bundled with Node.js)
- **VS Code**

TypeScript is a dev dependency — no global install needed.

You'll also need credentials for the `kyukibug` marketplace publisher
(get these from the previous maintainer).

## Getting started

```bash
git clone https://github.com/kyukibug/eecs280-setup.git
cd eecs280-setup
npm install
npm run compile
```

`npm run compile` produces `out/extension.js`, which `package.json` points
to as the entry point.

## Project layout

```
eecs280-setup/
├── package.json         ← Manifest: commands, settings, dependencies.
│                          Most config changes happen here.
├── src/
│   └── extension.ts     ← Detects OS, runs the right script, applies
│                          LLDB settings.
├── scripts/
│   ├── verify-macos.sh
│   ├── verify-wsl.sh
│   └── verify-linux.sh
├── images/icon.png      ← 128x128 marketplace icon
├── README.md            ← Marketplace listing (student-facing)
├── MAINTAINING.md       ← This file
├── LICENSE
├── tsconfig.json
├── .vscodeignore        ← Excluded from the .vsix
└── .gitignore
```

## How it fits together

```
Student installs extension
        │
        ├─► package.json extensionDependencies
        │   → Auto-installs C/C++, CodeLLDB, WSL extensions
        │
        ├─► package.json configurationDefaults
        │   → Sets chat.disableAIFeatures = true
        │
        ├─► extension.ts activate()
        │   → Sets lldb.showDisassembly = "never"
        │
        └─► Student runs "EECS 280: Verify Setup"
            → detectPlatform() → runs scripts/verify-{macos,wsl,linux}.sh
```

## Development workflow

### Fast iteration (recommended for TypeScript changes)

1. Open the project in VS Code
2. Press `F5` — launches a new VS Code window with the extension loaded
3. Run `Cmd+Shift+P → EECS 280: Verify Setup` in the new window
4. Edit, save, reload

Use watch mode to auto-recompile on save:

```bash
npm run watch
```

Script changes don't need recompilation — just re-run the command.

### Full install test (before publishing)

```bash
npm run compile
npm run package
code --install-extension eecs280-setup-X.X.X.vsix
```

Restart VS Code, then verify:
- `Cmd+Shift+P → EECS 280: Verify Setup` runs cleanly
- Copilot icon is hidden (AI features disabled)
- `lldb.showDisassembly` is set to `"never"` in settings

To uninstall:

```bash
code --uninstall-extension kyukibug.eecs280-setup
```

## Common tasks

### Add a tool check to a verify script

Edit the relevant script in `scripts/` following the existing pattern:

```bash
if command -v valgrind &>/dev/null; then
    pass "valgrind is installed."
else
    fail "valgrind is NOT installed."
    APT_PACKAGES_NEEDED+=("valgrind")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
```

Update the section header count if needed (e.g., `[3/4]` → `[3/5]`).

### Add a required VS Code extension

Edit `package.json` → `extensionDependencies`. It auto-installs for all
students on the next update.

### Change a VS Code setting

- **Built-in setting** (e.g., `chat.disableAIFeatures`): edit
  `package.json` → `contributes.configurationDefaults`.
- **Setting owned by another extension** (e.g., `lldb.showDisassembly`):
  edit `src/extension.ts` → the `vscode.workspace.getConfiguration()`
  block in `activate()`. VS Code rejects third-party settings in
  `configurationDefaults` at manifest validation.

### Add a new command

1. Add to `package.json` → `contributes.commands`:
   ```json
   {
       "command": "eecs280.newCommand",
       "title": "EECS 280: New Command",
       "category": "EECS 280"
   }
   ```
2. Register in `src/extension.ts` → `activate()`:
   ```typescript
   const newCmd = vscode.commands.registerCommand("eecs280.newCommand", () => {
       // ...
   });
   context.subscriptions.push(newCmd);
   ```

## Publishing an update

1. **Make your changes** and test with `F5` and/or a local `.vsix` install.
2. **Bump the version** in `package.json`:
   - Bug fix: `1.0.0` → `1.0.1`
   - New feature: `1.0.0` → `1.1.0`
3. **Build**:
   ```bash
   npm run compile
   npm run package
   ```
   Produces `eecs280-setup-X.X.X.vsix`.
4. **Upload** at https://marketplace.visualstudio.com/manage → `kyukibug`
   → the extension → **Update** → upload the `.vsix`.
5. **Verify** at https://marketplace.visualstudio.com/items?itemName=kyukibug.eecs280-setup

Students get the update automatically on next VS Code restart. Updates
typically go live within minutes; the first-ever publish of a new
extension can take 24–48 hours for review.

To pull a bad version: on the marketplace page, click the extension →
**Unpublish**.

## Troubleshooting

**`npm run compile` fails with type errors.** Run `npm install`. If that
doesn't help, delete `node_modules/` and `package-lock.json` and reinstall.

**`npm run package` warns about missing icon / LICENSE / repository.**
Make sure `images/icon.png` (128x128 PNG), `LICENSE`, and a valid
`repository.url` in `package.json` all exist.

**Extension doesn't activate under F5.** Open the Output panel, select
**Extension Host** from the dropdown, and look for errors. Usually a
TypeScript compile error.