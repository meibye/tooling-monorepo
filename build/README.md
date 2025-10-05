# Build Folder (CMD) – Tooling Monorepo

This folder contains **Windows CMD** and PowerShell scripts to manage the runtime tree at `C:\Tools` and the monorepo at `D:\Dev\tooling-monorepo` or `C:\Dev\tooling-monorepo`.  
These scripts automate scaffolding, building, publishing, deployment, and version management for both standalone tools and OneMore plugins.

## Script Overview

- **init_tools_root.cmd**  
  Initializes the `C:\Tools` directory structure for tool deployment (creates `apps\ps`, `apps\py`, etc.).

- **init_monorepo.cmd**  
  Sets up the monorepo folder structure, including plugins and tools, with example folders and README files.

- **new_tool_source.cmd**  
  Scaffolds a new tool (PowerShell, Python, CMD, Bash, Zsh) in the monorepo under `tools\<family>\<app>\src`, creating the necessary folders, a starter script, and updating the README.

- **new_onemore_plugin.cmd**  
  Scaffolds a new OneMore plugin under `plugins\onemore\<PluginName>\src`, with a starter script and README.

- **list_tools.cmd**  
  Lists all developed tools in the monorepo, showing their family and app names in a formatted table.

- **build-publish-tool.cmd / build-publish-tool.ps1**  
  Builds and publishes all tools and plugins: zips their source folders, computes hashes, and updates or creates manifests in the local Scoop bucket.

- **scan-update-bucket.cmd / scan-update-bucket.ps1**  
  Scans the monorepo for new, updated, or deleted tools/plugins and updates the bucket manifests accordingly (removes obsolete manifests, adds new ones, and triggers builds for changed items).

- **auto-update-tools.cmd / auto-update-tools.ps1**  
  Checks all deployed tools against their manifests and updates them if a newer version is available (extracts new artifacts and updates symlinks).

- **check-tool-version.cmd / check-tool-version.ps1**  
  Displays the version of a specified tool as defined in the bucket manifest and the currently deployed version.

## Development & Update Process for OneMore Plugins and Tools

1. **Scaffold a New Plugin or Tool**
   - For a OneMore plugin:  
     Run `new_onemore_plugin.cmd defrepo <PluginName>`
   - For a tool:  
     Run `new_tool_source.cmd defrepo <Family> <App> [Tool]`  
     (Family: `ps`, `py`, `cmd`, `bash`, `zsh`)

2. **Develop Your Script(s)**
   - Edit your scripts in the created `src` folder.
   - Update the README.md as needed.

3. **Build and Publish**
   - Run `build-publish-tool.cmd -Version <version>`  
     This zips the source, computes the hash, and updates the manifest in the local bucket.

4. **Scan and Update Bucket**
   - Run `scan-update-bucket.cmd`  
     This removes manifests for deleted tools/plugins and publishes new/changed ones.

5. **Deploy or Update Tools**
   - Run `auto-update-tools.cmd`  
     This checks for new versions and updates the deployed tools in `C:\Tools\apps`.

6. **Check Tool Version**
   - Run `check-tool-version.cmd -App <AppName>`  
     Shows the version in the bucket and the currently deployed version.

## Notes

- Do **not** add the build folder to PATH. These are developer scripts.
- Keep `%USERPROFILE%\scoop\shims` on PATH for runtime access to installed tools.
- For more information on Scoop, see the [Scoop Wiki](https://github.com/ScoopInstaller/Scoop/wiki).

## Quick start
```cmd
init_tools_root.cmd C:\Tools
init_monorepo.cmd defrepo

new_onemore_plugin.cmd defrepo ClipTools
new_tool_source.cmd defrepo py my-py-tool

build-publish-tool.cmd -Version 2025.09.01
scan-update-bucket.cmd

auto-update-tools.cmd
check-tool-version.cmd -App my-py-tool
```
