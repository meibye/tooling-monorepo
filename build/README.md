# Build Folder – Tooling Monorepo

This folder contains **Windows CMD** and PowerShell scripts to manage the runtime tree at `C:\Tools` and the monorepo at `D:\Dev\tooling-monorepo` or `C:\Dev\tooling-monorepo`.  
These scripts automate scaffolding, building, publishing, deployment, version management, and developer utilities for both standalone tools and OneMore plugins.

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
- **Deployment & Updates:** Automatically update installed tools to match the latest manifest versions with `bucket-deploy.cmd`/`.ps1`.
- **Version Checking:** Compare deployed tool/plugin versions with bucket manifests using `bucket-check-version.cmd`/`.ps1`.
- **Artifact Cleanup:** Remove published artifacts and manifests with `bucket-clean-artifacts.ps1`.
- **Listing & Initialization:** List all tools, initialize monorepo and tools root structure, unblock scripts, and touch files as needed.
- **Filtering:** Use `dev-filter-tool.ps1` to filter tools and manifests by family, app, and tool.
- **Other Utilities:** Print the PATH, unblock scripts, update file timestamps, etc.

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

| Script | Parameters | Description |
|--------|------------|-------------|
| **dev-find-powershell.cmd** | `ScriptName`, `Extension`, `[Args...]` | Locates and runs the corresponding PowerShell script, forwarding all user arguments. |
| **dev-init-tools-root.cmd** | `[Root]` | Initializes the tools root folder. <br>**Root:** Optional path for tools (default: `C:\Tools`). |
| **dev-init-monorepo.cmd** | `[RepoRoot\|defrepo]` | Sets up the monorepo folder structure. <br>**RepoRoot:** Optional repo root, or 'defrepo' to auto-select D: or C:. |
| **dev-new-tool.cmd** | `<RepoRoot\|defrepo> <Family> <App> [Tool]` | Scaffolds a new tool in the monorepo. <br>**RepoRoot:** Repo root or 'defrepo'. <br>**Family:** Tool type (`ps`, `py`, `cmd`, `bash`, `zsh`). <br>**App:** Folder grouping. <br>**Tool:** (Optional) tool source file name. |
| **dev-new-plugin.cmd** | `<RepoRoot\|defrepo> <PluginName>` | Scaffolds a new OneMore plugin. <br>**RepoRoot:** Repo root or 'defrepo'. <br>**PluginName:** Name of the plugin. |
| **dev-list-tools.cmd** | `[RepoRoot\|defrepo]` | Lists all developed tools in the monorepo. <br>**RepoRoot:** Optional repo root, or 'defrepo'. |
| **dev-print-path.ps1** | *(none)* | Prints each entry in the current `PATH` environment variable. |
| **dev-unblock-script.ps1** | `-Path <FilePath>` | Unblocks a specified file to allow script execution. <br>**Path:** Path to the file. |
| **dev-touch-file.ps1** | `-Path <FilePath>` | Updates the modification date and time of a file to now. <br>**Path:** Path to the file. |
| **dev-filter-tool.ps1** | `-Type <dev\|bucket>`, `-Location <path>`, `-Family <family>`, `-App <app>`, `-Tool <tool>` | Returns a table/list of tool script paths filtered by family, app, and tool. Used by other build scripts. |
| **bucket-publish.cmd / bucket-publish.ps1** | `-Version <version>`, `-OnlyChanged`, `-CommitAndSync`, `-Family <family>`, `-App <app>`, `-Tool <tool>`, `-ShowVersions` | Builds and publishes all tools and plugins. <br>**Version:** Version string for artifacts. <br>**OnlyChanged:** Only publish changed items. <br>**CommitAndSync:** Commit/push manifests and zips to git. <br>**Family/App/Tool:** Filter by family/app/tool. <br>**ShowVersions:** Show all considered versions for each app. |
| **bucket-scan-update.cmd / bucket-scan-update.ps1** | `-NoPublish` | Scans for new/changed/deleted tools/plugins and updates bucket manifests. <br>**NoPublish:** Skip publishing, only cleanup. |
| **bucket-deploy.cmd / bucket-deploy.ps1** | `-Family <family>`, `-App <app>`, `-Tool <tool>` | Deploys and updates installed tools according to bucket manifests. <br>**Family/App/Tool:** Filter by family/app/tool. |
| **bucket-check-version.cmd / bucket-check-version.ps1** | `-Family <family>`, `-App <app>`, `-Tool <tool>` | Displays the version in the bucket manifest and the deployed version. Also lists available artifact versions (local and GitHub), grouping more than 5 per line. |
| **bucket-clean-artifacts.ps1** | `-Family <family>`, `-App <app>`, `-Tool <tool>` | Deletes published manifests and artifacts from the bucket and artifacts folder. <br>**Family/App/Tool:** Filter by family/app/tool. |

---

## Development & Update Process for OneMore Plugins and Tools

1. **Scaffold a New Plugin or Tool**
   - For a OneMore plugin:  
     Run `dev-new-plugin.cmd defrepo <PluginName>`
   - For a tool:  
     Run `dev-new-tool.cmd defrepo <Family> <App> [Tool]`  
     (Family: `ps`, `py`, `cmd`, `bash`

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
   - Run `bucket-deploy.cmd`  
     This checks for new versions and updates the deployed tools in `C:\Tools\apps`.

6. **Check Tool Version**
   - Run `bucket-check-version.cmd -App <AppName>`  
     Shows the version in the bucket and the currently deployed version, and lists available artifact versions.

7. **Clean Publish Artifacts (Optional)**  
   - Run `bucket-clean-artifacts.ps1 -App <AppName>`  
     Deletes published artifacts and manifests for the specified app.

8. **Other Utilities**
   - Use `dev-touch-file.ps1` to update file modification timestamps.
   - Use `dev-unblock-script.ps1` to unblock downloaded scripts.

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

## Testing the Build Scripts

To ensure reliability and maintainability, you can add **unit tests** for the PowerShell scripts in the `build` folder using [Pester](https://pester.dev/), the standard PowerShell testing framework.

### Recommended Approach

1. **Create a `tests/` folder inside `build/`**  
   Place all test scripts in `d:\Dev\tooling-monorepo\build\tests\`.

2. **Write Pester tests for each script**  
   For each `.ps1` script, create a corresponding `*.Tests.ps1` file.  
   Example:  
   - `bucket-publish.ps1` → `tests/bucket-publish.Tests.ps1`
   - `dev-filter-tool.ps1` → `tests/dev-filter-tool.Tests.ps1`

3. **Test Structure Example**

   ```powershell
   # filepath: d:\Dev\tooling-monorepo\build\tests\dev-filter-tool.Tests.ps1
   Describe "dev-filter-tool.ps1" {
       It "Returns tools for default parameters" {
           $result = & "$PSScriptRoot\..\dev-filter-tool.ps1"
           $result | Should -Not -BeNullOrEmpty
       }
       It "Filters by Family" {
           $result = & "$PSScriptRoot\..\dev-filter-tool.ps1" -Family ps
           $result | Should -All { $_.Family -eq "ps" }
       }
       # Add more tests for App, Tool, error handling, etc.
   }
   ```

4. **Mocking and Isolation**  
   - Use Pester's `Mock` and `InModuleScope` to isolate file system operations.
   - Use temporary folders/files for destructive tests (e.g., artifact cleanup).
   - Avoid running tests that modify real artifacts or buckets unless in a CI/test environment.

5. **Run All Tests**

   From the `build` folder, run:

   ```powershell
   Invoke-Pester -Path .\tests
   ```

   Or, for a single test file:

   ```powershell
   Invoke-Pester -Path .\tests\bucket-publish.Tests.ps1
   ```

6. **Continuous Integration**  
   - Integrate Pester tests into your CI pipeline (e.g., GitHub Actions, Azure DevOps).
   - Fail builds if any test fails.

---

**Note:**  
For `.cmd` scripts, you can create wrapper PowerShell tests that invoke the `.cmd` file and check the output, exit code, or side effects.

**Example:**
```powershell
Describe "dev-list-tools.cmd" {
    It "Runs and outputs expected header" {
        $output = & cmd /c "$PSScriptRoot\..\dev-list-tools.cmd"
        $output | Should -Match "Family"
    }
}
```

---

**Summary Table**

| Script                | Test File                                 | Notes                        |
|-----------------------|-------------------------------------------|------------------------------|
| bucket-publish.ps1    | tests/bucket-publish.Tests.ps1            | Use mocks for file ops       |
| bucket-scan-update.ps1| tests/bucket-scan-update.Tests.ps1        | Use temp dirs for manifests  |
| dev-filter-tool.ps1   | tests/dev-filter-tool.Tests.ps1           | Test all filter params       |
| dev-list-tools.cmd    | tests/dev-list-tools.Tests.ps1            | Test output parsing          |
| ...                   | ...                                       | ...                          |

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

bucket-deploy.cmd
bucket-check-version.cmd -App my-py-tool
bucket-clean-artifacts.ps1 -App my-py-tool
dev-touch-file.ps1 -Path "C:\path\to\yourfile.txt"
dev-unblock-script.ps1 -Path "C:\path\to\file.ps1"
```
