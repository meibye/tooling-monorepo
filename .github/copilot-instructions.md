# Copilot Instructions for tooling-monorepo

## Overview
This monorepo manages the development, packaging, and deployment of cross-platform CLI tools and OneMore plugins. It is designed for Windows-first workflows, using Scoop for installation and PowerShell/CMD for automation.

## Key Structure
- `build/`: Automation scripts for scaffolding, building, publishing, and updating tools/plugins. **These are developer utilities only and are NOT managed by Scoop.**
- `tools/`: Source code for tools, organized by language family (`ps`, `py`, `cmd`, `bash`, `zsh`). Each tool has a `src/` folder for implementation.
- `plugins/onemore/`: OneMore plugins, each in its own folder with a `src/` directory.
- `meibye-bucket/`: Scoop bucket manifests for tool/plugin installation.

## Essential Workflows
- **Scaffold a new tool:**
  - Run `build/dev-new-tool.cmd defrepo <Family> <App> [Tool]` to create a new tool skeleton.
- **Scaffold a new plugin:**
  - Run `build/dev-new-plugin.cmd defrepo <PluginName>`.
- **Build & publish:**
  - Use `build/bucket-publish.cmd` or `.ps1` to zip sources, compute hashes, and update manifests.
- **Update bucket:**
  - Use `build/bucket-scan-update.cmd` or `.ps1` to sync manifests with source changes.
- **Auto-update deployed tools:**
  - Use `build/bucket-auto-update.cmd` or `.ps1` to update installed tools based on manifest versions.
- **List all tools:**
  - Run `build/dev-list-tools.cmd` for a summary table.

## Conventions & Patterns
- **Tool structure:** Each tool/plugin lives in its own folder under the appropriate family, with all code in `src/`.
- **README-driven:** Each tool/plugin should have a `README.md` in its root and/or `src/` describing usage and dependencies.
- **PowerShell modules:** Some tools (e.g., `MoveWindowToNextDesktop`) depend on external modules (see their `README.md`).
- **No hardcoded paths:** Scripts use variables or expect standard locations (`C:\Tools`, `D:\Dev`, etc.).
- **Cross-shell:** Prefer `.cmd` for Windows batch, `.ps1` for PowerShell; both are often provided for key scripts.
- **Build scripts are not end-user tools:**  
  Do **not** add `build/` scripts to your PATH or create Scoop manifests for them.  
  Only tools/plugins in `tools/` and `plugins/` are Scoop-managed.

## Integration Points
- **Scoop:** All installable tools/plugins are described in `meibye-bucket/bucket/` manifests.
- **PowerToys:** Some tools are designed to be triggered by PowerToys Keyboard Manager hotkeys (see relevant `README.md`).

## Examples
- To move a window to the next desktop, see `tools/ps/MoveWindowToNextDesktop/src/README.md` for PowerShell and PowerToys integration.
- To add a new Python tool: `build/dev-new-tool.cmd defrepo py my-py-tool` then edit `tools/py/my-py-tool/src/`.
