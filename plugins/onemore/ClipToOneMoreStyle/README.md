## ClipToOneMoreStyle (OneMore plugin)

OneMore Plugin: Insert clipboard content into OneNote page, scrub ChatGPT identifiers and banners, map to standard styles (h1..h6/p), emit REAL bullet/numbered lists, and prep for Colorize.

### Debug & Logs
- `-VerboseLog` : Enables verbose logging and transcript
- `-LogPath "X:\...\file.log"` : Override log file (default: `%TEMP%\ClipToOneMoreStyle.log`)
- `-DiagDump` : Write diagnostics bundle (formats, blocks.json, raw/final snippets)
- `-DiagDir  "X:\...\dir"` : Override diagnostics directory (default depends on snapshot/page)
- `-DebugWait` : Pause at start so you can attach VS Code debugger

---

**OneMore calls this as:**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ClipToOneMoreStyle.ps1 "<tempPageXmlPath>"
```

