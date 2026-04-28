# Maintaining the EECS 280 Setup Extension

Guide for the TA maintaining this extension. Covers local development,
making changes, and publishing updates to the VS Code Marketplace.

## Prerequisites

- **Node.js** v18+ (check: `node --version`) — https://nodejs.org
- **npm** (bundled with Node.js)
- **VS Code**

TypeScript is a dev dependency — no global install needed.

You'll also need credentials for the `eecs280` marketplace publisher
(get these from the previous maintainer).

## Getting started

```bash
git clone https://github.com/eecs280staff/vscode-setup280.git
cd vscode-setup280
npm install
npm run compile
```

`npm run compile` produces `out/extension.js`, which `package.json` points
to as the entry point.

## Project layout

```
vscode-setup280/
├── package.json         ← Manifest: commands, settings, dependencies.
│                          Most config changes happen here.
├── src/
│   └── extension.ts     ← Detects OS, runs the right script, applies
│                          settings.
├── scripts/
│   ├── verify_macos.sh
│   ├── verify_wsl.sh
│   └── verify_linux.sh
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
        │   → Auto-installs C/C++ and CodeLLDB extensions
        │
        ├─► package.json configurationDefaults
        │   → Sets chat.disableAIFeatures = true
        │
        ├─► extension.ts activate()
        │   → Sets lldb.showDisassembly = "never"
        │
        └─► Student runs "EECS 280: Verify Setup"
            → detectPlatform() → runs scripts/verify_{macos,wsl,linux}.sh
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
code --install-extension setup280-X.X.X.vsix
```

Restart VS Code, then verify:
- `Cmd+Shift+P → EECS 280: Verify Setup` runs cleanly
- Copilot icon is hidden (AI features disabled)
- `lldb.showDisassembly` is set to `"never"` in settings

To uninstall:

```bash
code --uninstall-extension eecs280.setup280
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

Publishing is automated. Push a `vX.Y.Z` tag and GitHub Actions builds
and publishes to the Marketplace.

1. **Make your changes** and test with `F5` and/or a local `.vsix` install.
2. **Bump the version** in `package.json`:
   - Bug fix: `1.0.0` → `1.0.1`
   - New feature: `1.0.0` → `1.1.0`
3. **Commit and tag**:
   ```bash
   git commit -am "Release vX.Y.Z"
   git push
   git tag vX.Y.Z
   git push --tags
   ```
4. **Watch the run** at https://github.com/eecs280staff/vscode-setup280/actions.
   The `Publish` workflow checks the tag matches `package.json`, compiles,
   and runs `vsce publish`.
5. **Verify** at https://marketplace.visualstudio.com/items?itemName=eecs280.setup280.

Students get the update automatically on next VS Code restart. Updates
typically go live within minutes; the first-ever publish of a new
extension can take 24–48 hours for review.

To pull a bad version: on the marketplace page, click the extension →
**Unpublish**.

### Manual publish (fallback)

If the GitHub Actions workflow is broken, publish locally:

```bash
npm run compile
npm run package
npm run publish     # needs VSCE_PAT in env, or run `vsce login eecs280` first
```

Or upload `setup280-X.X.X.vsix` at
https://marketplace.visualstudio.com/manage → `eecs280` → the extension
→ **Update**.

### One-time CI setup

The publish workflow needs a Marketplace Personal Access Token stored as
a GitHub Actions secret:

1. Sign in to https://dev.azure.com with the account that owns the
   `eecs280` Marketplace publisher.
2. **User settings** (top right) → **Personal access tokens** → **New Token**.
   - **Organization**: All accessible organizations
   - **Scopes**: **Custom defined** → **Marketplace** → **Manage**
   - Set an expiration you'll remember to renew (max 1 year).
3. Copy the token (you only see it once).
4. In GitHub: https://github.com/eecs280staff/vscode-setup280/settings/secrets/actions
   → **New repository secret** → name `VSCE_PAT`, value the token.

Renew the token before it expires; the publish workflow will start
failing with a 401 from `vsce` once it does.

Reference: https://code.visualstudio.com/api/working-with-extensions/publishing-extension#get-a-personal-access-token

## Troubleshooting

**`npm run compile` fails with type errors.** Run `npm install`. If that
doesn't help, delete `node_modules/` and `package-lock.json` and reinstall.

**`npm run package` warns about missing icon / LICENSE / repository.**
Make sure `images/icon.png` (128x128 PNG), `LICENSE`, and a valid
`repository.url` in `package.json` all exist.

**Extension doesn't activate under F5.** Open the Output panel, select
**Extension Host** from the dropdown, and look for errors. Usually a
TypeScript compile error.
