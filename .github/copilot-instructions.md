# Copilot Instructions for tooling-monorepo

## Project Overview
This monorepo manages the development, packaging, and deployment of cross-platform CLI tools and OneMore plugins. It is Windows-first, using Scoop for installation and PowerShell/CMD for automation. The structure and workflows are designed for rapid tool/plugin iteration and seamless end-user updates.

## Key Architecture & Structure
- **`build/`**: Developer-only automation scripts for scaffolding, building, publishing, updating, filtering, and utility tasks. **Never add these to PATH or Scoop.**
- **`tools/`**: Source code for tools, organized by language (`ps`, `py`, `cmd`, `bash`, `zsh`). Each tool has a `src/` folder for implementation and a `README.md` for usage.
- **`plugins/onemore/`**: OneMore plugins, each in its own folder with a `src/` directory and `README.md`.
- **`meibye-bucket/`**: Scoop bucket manifests for installable tools/plugins.

## Essential Developer Workflows
- **Scaffold a new tool:**  
  `build/dev-new-tool.cmd defrepo <Family> <App> [Tool]`
- **Scaffold a new plugin:**  
  `build/dev-new-plugin.cmd defrepo <PluginName>`
- **Build & publish:**  
  `build/bucket-publish.cmd -Version <version>`
- **Update bucket:**  
  `build/bucket-scan-update.cmd`
- **Deploy/update tools:**  
  `build/bucket-deploy.cmd`
- **List all tools:**  
  `build/dev-list-tools.cmd`
- **Filter tools/manifests:**  
  `build/dev-filter-tool.ps1 -Type <dev|bucket> -Family <family> -App <app> -Tool <tool>`
- **Test scripts:**  
  Place Pester tests in `build/tests/` as `*.Tests.ps1` and run with `Invoke-Pester -Path .\tests`

## Project-Specific Conventions
- **Tool/plugin structure:** All code in `src/`, with a `README.md` describing usage and dependencies.
- **No hardcoded paths:** Scripts use variables or expect standard locations (`C:\Tools`, `D:\Dev`, etc.).
- **Cross-shell:** `.cmd` for batch, `.ps1` for PowerShell; both often provided for key scripts.
- **PowerShell Core required** for most PowerShell tools (`pwsh`).
- **Build scripts are not end-user tools:** Only `tools/` and `plugins/` are Scoop-managed.

## Integration Points
- **Scoop:** All installable tools/plugins are described in `meibye-bucket/bucket/` manifests. End-users install/update via Scoop.
- **PowerToys:** Some tools (e.g., `MoveWindowToNextDesktop`) are designed for hotkey integration via PowerToys Keyboard Manager.
- **External modules:** Some tools require PowerShell modules (see their `README.md`).


## Examples & References
- **MoveWindowToNextDesktop:** See `tools/ps/MoveWindowToNextDesktop/src/README.md` for PowerShell and PowerToys integration.
- **ClipToOneMoreStyle:** See `plugins/onemore/ClipToOneMoreStyle/README.md` for plugin usage and debug options.
- **winutil:** See `tools/ps/tools/README.md` for Windows utility installer details.

## Quick Start
```cmd
# Initialize tools root and monorepo
build/dev-init-tools-root.cmd C:\Tools
build/dev-init-monorepo.cmd defrepo

# Scaffold new plugin/tool
build/dev-new-plugin.cmd defrepo MyPlugin
build/dev-new-tool.cmd defrepo py my-py-tool

# Build, publish, deploy
build/bucket-publish.cmd -Version 0.1.1
build/bucket-scan-update.cmd
build/bucket-deploy.cmd
```

## Testing
- Use [Pester](https://pester.dev/) (external site) for PowerShell script tests in `build/tests/`.
- For `.cmd` scripts, create wrapper PowerShell tests that invoke the `.cmd` and check output.

---
**Do NOT add `build/` scripts to PATH or create Scoop manifests for them. Only `tools/` and `plugins/` are end-user installable.**
