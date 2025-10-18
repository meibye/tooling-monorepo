# Build Folder – Tooling Monorepo

This folder contains **Windows CMD** and PowerShell scripts to manage the runtime tree at `C:\Tools` and the monorepo at `D:\Dev\tooling-monorepo` or `C:\Dev\tooling-monorepo`.  
These scripts automate scaffolding, building, publishing, deployment, and version management for both standalone tools and OneMore plugins.

> **Important:**  
> The scripts in the `build/` folder are **developer utilities only**.  
> **Do not** add `build/` scripts to your PATH or manage them with Scoop.  
> Only tools and plugins in `tools/` and `plugins/` are Scoop-installable.

---

## Major Workflows: Scoop Application Management

This monorepo is designed for seamless integration with [Scoop](https://scoop.sh/), a Windows command-line installer.  
The build scripts automate the full lifecycle for tools and plugins, including:

- **Scaffolding:** Quickly create new tool/plugin skeletons with `dev-new-tool.cmd` and `dev-new-plugin.cmd`.
- **Building & Publishing:** Package sources, compute hashes, and update Scoop manifests with `bucket-publish.cmd`/`.ps1`.
- **Bucket Synchronization:** Remove obsolete manifests and publish new/changed ones with `bucket-scan-update.cmd`/`.ps1`.
- **Deployment & Updates:** Automatically update installed tools to match the latest manifest versions with `bucket-auto-update.cmd`/`.ps1`.
- **Version Checking:** Compare deployed tool/plugin versions with bucket manifests using `bucket-check-version.cmd`/`.ps1`.
- **Artifact Cleanup:** Remove published artifacts and manifests with `bucket-clean-artifacts.ps1`.
- **Listing & Initialization:** List all tools, initialize monorepo and tools root structure, and unblock scripts as needed.

**Scoop Integration Highlights:**
- All installable tools/plugins are described in `meibye-bucket/bucket/` manifests.
- The build scripts ensure that published artifacts and manifests are always in sync with the source tree.
- End-users install and update tools via Scoop, while developers use these scripts to manage the lifecycle.

---

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

---

## Script Overview

- **dev-find-powershell.cmd**  
  Shared helper script used by other `.cmd` scripts to locate and run the corresponding PowerShell script, forwarding all user arguments correctly.

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

- **dev-print-path.ps1**  
  Prints each entry in the current `PATH` environment variable.

- **dev-unblock-script.ps1**  
  Unblocks a specified file to allow script execution (removes Zone.Identifier).

- **bucket-publish.cmd / bucket-publish.ps1**  
  Builds and publishes all tools and plugins: zips their source folders, computes hashes, and updates or creates manifests in the local Scoop bucket.

- **bucket-scan-update.cmd / bucket-scan-update.ps1**  
  Scans the monorepo for new, updated, or deleted tools/plugins and updates the bucket manifests accordingly (removes obsolete manifests, adds new ones, and triggers builds for changed items).

- **bucket-auto-update.cmd / bucket-auto-update.ps1**  
  Checks all deployed tools against their manifests and updates them if a newer version is available (extracts new artifacts and updates symlinks).

- **bucket-check-version.cmd / bucket-check-version.ps1**  
  Displays the version of a specified tool as defined in the bucket manifest and the currently deployed version.

- **bucket-clean-artifacts.ps1**  
  Deletes published manifests and artifacts from the bucket and `out\artifacts` folder.  
  Lists only apps (tools/plugins) that currently have artifacts or manifests to delete, grouped by family, and asks for confirmation before proceeding.  
  Supports an optional `-App` parameter to restrict deletion to a specific app.

---

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

---

## Using Applications and Scripts via Scoop (meibye-bucket)

Once your tools and plugins are published and the manifests are present in the `meibye-bucket`, you (or any user) can install and use them via Scoop.

### 1. Add the meibye-bucket to Scoop

If you haven't already, add the bucket (local or remote):

```powershell
scoop bucket add meibye D:\Dev\meibye-bucket\bucket
```
or
```powershell
scoop bucket add meibye https://github.com/meibye/meibye-bucket
```

### 2. Install an Application

To install a tool or plugin (e.g., `MoveWindowToNextDesktop`):

```powershell
scoop install MoveWindowToNextDesktop
```

Scoop will:
- Download the published artifact (zip) as described in the manifest.
- Extract it to the appropriate folder under `C:\Users\<User>\scoop\apps\<AppName>\<Version>\`.
- Create a shim (shortcut) in `%USERPROFILE%\scoop\shims` for each executable/script listed in the manifest's `bin` array.

### 3. Run the Application

After installation, you can run the tool from any command prompt or PowerShell window:

```powershell
MoveWindowToNextDesktop.ps1
```
or, for batch/CMD tools:
```cmd
my-cmd-tool.cmd
```

Scoop ensures that the `shims` directory is on your `PATH`, so the commands are globally available.

### 4. Update Applications

To update all installed tools to the latest version in the bucket:

```powershell
scoop update *
```

Or update a specific tool:

```powershell
scoop update MoveWindowToNextDesktop
```

### 5. Uninstall Applications

To remove a tool:

```powershell
scoop uninstall MoveWindowToNextDesktop
```

### 6. Developer Workflow

- Use the build scripts in this folder to scaffold, build, and publish new versions.
- After publishing, run `scoop update` to make the new version available to users.
- End-users only need to use Scoop commands; developers use the scripts in `build/` for management.

---

## Notes

- **Do NOT add the `build/` folder to your PATH.** These scripts are for developer use only and are not intended for end-user installation.
- **Do NOT create Scoop manifests for `build/` scripts.** Only tools and plugins in `tools/` and `plugins/` are managed by Scoop.
- Keep `%USERPROFILE%\scoop\shims` on PATH for runtime access to installed tools.
- For more information on Scoop, see the [Scoop Wiki](https://github.com/ScoopInstaller/Scoop/wiki).

---

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
