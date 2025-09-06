# Build Folder (CMD) – Tooling Monorepo

This folder contains **Windows CMD** scripts to manage the runtime tree at `C:\Tools` and the monorepo at `D:\Dev\tooling-monorepo`.

## Where to place
Unzip into: `D:\Dev\tooling-monorepo\build`

## PATH
Do **not** add the build folder to PATH. These are developer scripts. Keep `%USERPROFILE%\scoop\shims` on PATH.

## Quick start
```cmd
init_tools_root.cmd C:\Tools
init_monorepo.cmd D:\Dev\tooling-monorepo

new_onemore_plugin.cmd D:\Dev\tooling-monorepo ClipTools
new_tool_source.cmd D:\Dev\tooling-monorepo py my-py-tool

build_zip.cmd D:\Dev\tooling-monorepo plugins\onemore\ClipTools\src onemore-ClipTools 2025.09.01
deploy_to_tools.cmd onemore ClipTools 2025-09-01 D:\Dev\tooling-monorepo\out\artifacts\onemore-ClipTools-2025.09.01.zip

promote_app.cmd onemore ClipTools 2025-09-02
update_bucket_manifest.cmd D:\Dev\meibye-bucket onemore-ClipTools.json 2025.09.02 https://artifacts/onemore-ClipTools-2025.09.02.zip <SHA256> "ClipTools 2025.09.02"
```
