# Build Folder (CMD) – Tooling Monorepo

This folder contains **Windows CMD** and PowerShell scripts to manage the runtime tree at `C:\Tools` and the monorepo at `D:\Dev\tooling-monorepo` or `C:\Dev\tooling-monorepo`.  
These scripts automate scaffolding, building, publishing, deployment, and version management for both standalone tools and OneMore plugins.

> **Important:**  
> The scripts in the `build/` folder are **developer utilities only**.  
> **Do not** add `build/` scripts to your PATH or manage them with Scoop.  
> Only tools and plugins in `tools/` and `plugins/` are Scoop-installable.

## Prerequisites: Scoop, Git, and Repositories

Before using these scripts, ensure you have [Scoop](https://scoop.sh/) and [Git](https://git-scm.com/) installed.

### 1. Install Scoop

Open PowerShell as Administrator and run:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

### 2. Clone the Required Repositories

Clone both the tooling monorepo and the bucket:

```powershell
git clone https://github.com/meibye/tooling-monorepo.git D:\Dev\tooling-monorepo
git clone https://github.com/meibye/meibye-bucket.git D:\Dev\meibye-bucket
```

> Adjust the destination paths as needed.
****
### 3. Register the meibye-bucket with Scoop

Register your local or remote bucket with Scoop:

```powershell
scoop bucket add meibye D:\Dev\meibye-bucket\bucket
```
Or, to use the remote bucket:
```powershell
scoop bucket add meibye https://github.com/meibye/meibye-bucket
```

This allows Scoop to discover and install tools described in the bucket's manifest files.

### 4. About the Repositories

- **[meibye/tooling-monorepo](https://github.com/meibye/tooling-monorepo):**  
  Contains all source code, scripts, and plugins for your tools. This is where you develop and build your tools.

- **[meibye/meibye-bucket](https://github.com/meibye/meibye-bucket):**  
  Contains the Scoop bucket (a collection of manifest files) that describes how to install and update your tools.

## Script Overview

- **dev-find-powershell.cmd**  
  Shared helper script used by other `.cmd` scripts to locate and run the corresponding PowerShell script, forwarding all user arguments correctly. Prefer using this for new `.cmd` wrappers.

- **dev-init-tools-root.cmd**  
  Initializes the `C:\Tools` directory structure for tool deployment (creates `apps\ps`, `apps\py`, etc.).

- **dev-init-monorepo.cmd**  
  Sets up the monorepo folder structure, including plugins and tools, with example folders and README files.

- **dev-new-tool.cmd**  
  Scaffolds a new tool (PowerShell, Python, CMD, Bash, Zsh) in the monorepo under `tools\<family>\<app>\src`, creating the necessary folders, a starter script, and updating the README.

- **dev-new-plugin.cmd**  
  Scaffolds a new OneMore plugin under `plugins\onemore\<PluginName>\src`, with a starter script and README.

- **dev-list-tools.cmd**  
  Lists all developed tools in the monorepo, showing their family and app names in a formatted table.

- **bucket-publish.cmd / bucket-publish.ps1**  
  Builds and publishes all tools and plugins: zips their source folders, computes hashes, and updates or creates manifests in the local Scoop bucket.  
  The `.cmd` wrapper uses `dev-find-powershell.cmd` to ensure correct argument passing.

- **bucket-scan-update.cmd / bucket-scan-update.ps1**  
  Scans the monorepo for new, updated, or deleted tools/plugins and updates the bucket manifests accordingly (removes obsolete manifests, adds new ones, and triggers builds for changed items).  
  Uses the shared PowerShell script runner for consistency.

- **bucket-auto-update.cmd / bucket-auto-update.ps1**  
  Checks all deployed tools against their manifests and updates them if a newer version is available (extracts new **artifacts** and updates symlinks).  
  Uses the shared PowerShell script runner.

- **bucket-check-version.cmd / bucket-check-version.ps1**  
  Displays the version of a specified tool as defined in the bucket manifest and the currently deployed version.

- **bucket-clean-artifacts.ps1**  
  Deletes published manifests and artifacts from the bucket and `out\artifacts` folder.  
  Lists only apps (tools/plugins) that currently have artifacts or manifests to delete, grouped by family, and asks for confirmation before proceeding.  
  Supports an optional `-App` parameter to restrict deletion to a specific app.

## Development & Update Process for OneMore Plugins and Tools

1. **Scaffold a New Plugin or Tool**
   - For a OneMore plugin:  
     Run `dev-new-plugin.cmd defrepo <PluginName>`
   - For a tool:  
     Run `dev-new-tool.cmd defrepo <Family> <App> [Tool]`  
     (Family: `ps`, `py`, `cmd`, `bash`, `zsh`)

2. **Develop Your Script(s)**
   - Edit your scripts in the created `src` folder.
   - Update the README.md as needed.

3. **Build and Publish**
   - Run `bucket-publish.cmd -Version <version>`  
     This zips the source, computes the hash, and updates the manifest in the local bucket.

4. **Scan and Update Bucket**
   - Run `bucket-scan-update.cmd`  
     This removes manifests for deleted tools/plugins and publishes new/changed ones.

5. **Deploy or Update Tools**
   - Run `bucket-auto-update.cmd`  
     This checks for new versions and updates the deployed tools in `C:\Tools\apps`.

6. **Check Tool Version**
   - Run `bucket-check-version.cmd -App <AppName>`  
     Shows the version in the bucket and the currently deployed version.

7. **Clean Publish Artifacts (Optional)**  
   - Run `bucket-clean-artifacts.ps1 -App <AppName>`  
     Deletes published artifacts and manifests for the specified app.

## Notes

- **Do NOT add the `build/` folder to your PATH.** These scripts are for developer use only and are not intended for end-user installation.
- **Do NOT create Scoop manifests for `build/` scripts.** Only tools and plugins in `tools/` and `plugins/` are managed by Scoop.
- Keep `%USERPROFILE%\scoop\shims` on PATH for runtime access to installed tools.
- For more information on Scoop, see the [Scoop Wiki](https://github.com/ScoopInstaller/Scoop/wiki).

## Quick start
```cmd
dev-init-tools-root.cmd C:\Tools
dev-init-monorepo.cmd defrepo

dev-new-plugin.cmd defrepo ClipTools
dev-new-tool.cmd defrepo py my-py-tool

bucket-publish.cmd -Version 0.1.1
bucket-scan-update.cmd

bucket-auto-update.cmd
bucket-check-version.cmd -App my-py-tool
bucket-clean-artifacts.ps1 -App my-py-tool
```
