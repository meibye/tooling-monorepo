<#  ClipToOneMoreStyle.ps1
    OneMore Plugin: Insert clipboard content into OneNote page, scrub ChatGPT identifiers + banners,
    map to standard styles (h1..h6/p), emit REAL bullet/numbered lists, and prep for Colorize.

    Debug & Logs:
      -VerboseLog                 : enables verbose logging + transcript
      -LogPath "X:\...\file.log"  : override log file (default: %TEMP%\ClipToOneMoreStyle.log)
      -DiagDump                   : write diagnostics bundle (formats, blocks.json, raw/final snippets)
      -DiagDir  "X:\...\dir"      : override diagnostics directory (default depends on snapshot/page)
      -DebugWait                  : pause at start so you can attach VS Code debugger

    OneMore calls this as:
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File ClipToOneMoreStyle.ps1 "<tempPageXmlPath>"
#>

param(
  [Parameter(Mandatory=$true)][string]$PageXmlPath,

  # Debug & logging
  [switch]$VerboseLog,
  [string]$LogPath = "$env:TEMP\ClipToOneMoreStyle.log",
  [switch]$DiagDump,
  [string]$DiagDir,
  [switch]$DebugWait
)

$ErrorActionPreference = 'Stop'

# --- namespaces ----------------------------------------------------------------
$nsUrl = "http://schemas.microsoft.com/office/onenote/2013/onenote"

# --- logging helpers ------------------------------------------------------------
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:HadCode = $false

function Write-Log {
  param([string]$msg, [string]$lvl = "INFO")
  $line = "{0:u} [{1}] {2}" -f (Get-Date), $lvl.ToUpper(), $msg
  if ($VerboseLog) { Write-Verbose $line }
  Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}
function Use-Dir($p) {
  $dir = Split-Path -Path $p -Parent
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
}
function Write-File($p, $content) { Use-Dir $p; Set-Content -LiteralPath $p -Value $content -Encoding UTF8 }
function Write-Json($p, $obj) { Use-Dir $p; ($obj | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $p -Encoding UTF8 }

# transcript + first line
try {
  if ($VerboseLog) {
    try { Start-Transcript -Path $LogPath -Append | Out-Null } catch {}
    Write-Log "ClipToOrangePlus start. PID=$PID PageXmlPath='$PageXmlPath'"
  }
} catch {}

# --- debugger gate --------------------------------------------------------------
if ($DebugWait) {
  Write-Log "Waiting for debugger attach (-DebugWait)..." "DEBUG"
  $pidFile = Join-Path $env:TEMP "ClipToOrangePlus.pid"
  Write-File $pidFile $PID
  if (Get-Command Wait-Debugger -ErrorAction SilentlyContinue) {
    Wait-Debugger
  } else {
    while (-not $PSDebugContext) { Start-Sleep -Milliseconds 200 }
  }
}

# --- diagnostics dir ------------------------------------------------------------
if (-not $DiagDir) {
  $base = [IO.Path]::GetFileNameWithoutExtension($PageXmlPath)
  if (-not [string]::IsNullOrWhiteSpace($base)) {
    $DiagDir = Join-Path $env:TEMP ("ClipToOrangePlus_" + $base + ".diag")
  } else {
    $DiagDir = Join-Path $env:TEMP "ClipToOrangePlus.diag"
  }
}
if ($DiagDump) { Write-Log "Diagnostics folder: $DiagDir" "DEBUG" }

# --- clipboard helpers ----------------------------------------------------------
function Get-CfHtmlFragment {
  Add-Type -AssemblyName System.Windows.Forms
  $obj = [Windows.Forms.Clipboard]::GetDataObject()
  if ($obj -and $obj.GetDataPresent("HTML Format")) {
    $cf = [string]$obj.GetData("HTML Format")
    $sm='<!--StartFragment-->'; $em='<!--EndFragment-->'
    $s=$cf.IndexOf($sm); $e=$cf.IndexOf($em)
    if ($s -ge 0 -and $e -gt $s) { return $cf.Substring($s+$sm.Length, $e-$s-$sm.Length) }
    return $cf
  }
  return $null
}
function Get-ClipboardText { try { Get-Clipboard -Raw } catch { "" } }

# --- scrubbers (ChatGPT identifiers, footers, banners) -------------------------
function Remove-ChatGPTIdentifiersText([string]$t) {
  if ([string]::IsNullOrWhiteSpace($t)) { return $t }
  $lines = @()
  foreach ($line in $t -split "`r?`n") {
    $l = $line.Trim()

    # Roles & UI
    if ($l -match '^(User|Assistant|System)\s*:') { continue }
    if ($l -match '^(Copy code|Open in app|Try again|Regenerate|Model:|Powered by .*GPT|You are ChatGPT)\b') { continue }
    if ($l -match '^(ChatGPT|GPT-[^\s]+|OpenAI)\s*$') { continue }

    # Company footers / confidentiality / signatures
    if ($l -match '^(All rights reserved|©|\(c\)|Copyright\b|\bConfidential\b).*') { continue }
    if ($l -match '\bThis message (and any attachments|may contain confidential)\b.*') { continue }
    if ($l -match '^\W*(Best|Kind|Sincerely|Med venlig)\W*regards.*$') { continue }

    # Date banners (EN & DA)
    if ($l -match '^(Updated|Last updated|Opdateret)\s*[:\-–]\s*\w+\s+\d{1,2},?\s+\d{4}\b') { continue }
    if ($l -match '^\d{1,2}\s+\w+\s+\d{4}\b') { continue }
    if ($l -match '^\w+\s+\d{1,2},\s+\d{4}\b') { continue }
    if ($l -match '^\d{4}-\d{2}-\d{2}\b') { continue }

    # Inline artifacts
    $l = $l -replace ']*',''
    $l = $l -replace '\[Copied\]',''
    $l = $l -replace '\bChatGPT\b',''
    $l = $l -replace '\b(GPT-[\w\.-]+|OpenAI)\b',''

    # Bracket/divider lines
    if ($l -match '^\s*\[[^\]]+\]\s*$') { continue }
    if ($l -match '^\s*[—–-]{3,}\s*$') { continue }

    # Zero-width
    $l = $l -replace "[\u200B-\u200D\uFEFF]", ""
    if ($l.Trim().Length -gt 0) { $lines += $l }
  }
  ($lines -join "`r`n").Trim()
}

function Remove-ChatGPTIdentifiersHtml([string]$h) {
  if ([string]::IsNullOrWhiteSpace($h)) { return $h }
  $s = $h
  $s = $s -replace '(?is)<button[^>]*>.*?Copy code.*?</button>',''
  $s = $s -replace '(?is)<div[^>]*class="[^"]*(copy|toolbar|control|actions)[^"]*"[^>]*>.*?</div>',''
  $s = $s -replace '(?is)<span[^>]*>Copy code</span>',''
  $s = $s -replace '(?i)\bChatGPT\b',''
  $s = $s -replace '(?i)\bGPT-[\w\.-]+\b',''
  $s = $s -replace '(?i)\bOpenAI\b',''
  $s = $s -replace ']*',''
  $s = $s -replace '(?is)<footer[^>]*>.*?</footer>',''
  $s = $s -replace '(?is)<div[^>]*class="[^"]*(signature|footer|legal)[^"]*"[^>]*>.*?</div>',''
  $s = $s -replace '(?is)<p[^>]*>\s*(Updated|Last updated|Opdateret)\s*[:\-–].*?</p>',''
  $s = $s -replace '(?is)<p[^>]*>\s*\d{1,2}\s+\w+\s+\d{4}\s*</p>',''
  $s = $s -replace '(?is)<p[^>]*>\s*\w+\s+\d{1,2},\s+\d{4}\s*</p>',''
  $s = $s -replace '(?is)<p[^>]*>\s*\d{4}-\d{2}-\d{2}\s*</p>',''
  $s = $s -replace '(?is)<p[^>]*>\s*</p>',''
  $s = $s -replace '(?is)<span[^>]*>\s*</span>',''
  $s.Trim()
}

# --- parsing (headings, code, lists, paragraphs) --------------------------------
function Convert-Blocks([string]$htmlOrText, [bool]$isHtml) {
  $blocks = New-Object System.Collections.Generic.List[object]

  if ($isHtml) {
    $h = Remove-ChatGPTIdentifiersHtml $htmlOrText

    # Capture whole lists first
    [regex]::Matches($h, '(?is)<(ul|ol)\b[^>]*>(.*?)</\1>') | ForEach-Object {
      $kind = $_.Groups[1].Value.ToLower()
      $inner = $_.Groups[2].Value
      $items = New-Object System.Collections.Generic.List[string]
      [regex]::Matches($inner,'(?is)<li\b[^>]*>(.*?)</li>') | ForEach-Object {
        $item = ($_).Groups[1].Value
        $item = ($item -replace "<[^>]+>"," ") -replace "&nbsp;"," "
        $item = Remove-ChatGPTIdentifiersText $item
        $items.Add( ($item -replace '\s+',' ').Trim() )
      }
      if ($items.Count -gt 0) { $blocks.Add([pscustomobject]@{ kind="list"; listKind=$kind; items=$items }) }
    }

    # Remove lists to avoid double-capture of <p> in them
    $clean = $h -replace '(?is)<(ul|ol)\b[^>]*>.*?</\1>',' '

    $pairs = @(
      @{type="h1"; re="(?is)<h1\b[^>]*>(.*?)</h1>"},
      @{type="h2"; re="(?is)<h2\b[^>]*>(.*?)</h2>"},
      @{type="h3"; re="(?is)<h3\b[^>]*>(.*?)</h3>"},
      @{type="h4"; re="(?is)<h4\b[^>]*>(.*?)</h4>"},
      @{type="h5"; re="(?is)<h5\b[^>]*>(.*?)</h5>"},
      @{type="h6"; re="(?is)<h6\b[^>]*>(.*?)</h6>"},
      @{type="code"; re="(?is)<pre\b[^>]*>(.*?)</pre>"},
      @{type="p";   re="(?is)<p\b[^>]*>(.*?)</p>"}
    )
    foreach($p in $pairs){
      [regex]::Matches($clean,$p.re) | ForEach-Object {
        $t = ($_).Groups[1].Value
        $t = ($t -replace "<[^>]+>"," ") -replace "&nbsp;"," "
        $t = Remove-ChatGPTIdentifiersText $t
        $v = ($t -replace '\s+',' ').Trim()
        if ($v) {
          if ($p.type -eq "code") { $script:HadCode = $true }
          $blocks.Add([pscustomobject]@{ kind=$p.type; text=$v })
        }
      }
    }

  } else {
    $txt = Remove-ChatGPTIdentifiersText $htmlOrText
    $lines = $txt -split "`r?`n"
    $i = 0
    while ($i -lt $lines.Count) {
      $ln = $lines[$i].Trim()
      if ($ln -match '^(#{1,6})\s+(.*)$') {
        $blocks.Add([pscustomobject]@{ kind=("h"+$Matches[1].Length); text=$Matches[2] })
      }
      elseif ($ln -match '^(\d+)\.\s+(.*)$') {
        $items = New-Object System.Collections.Generic.List[string]
        while ($i -lt $lines.Count -and $lines[$i].Trim() -match '^\d+\.\s+(.*)$') { $items.Add($Matches[1].Trim()); $i++ }
        $i--; $blocks.Add([pscustomobject]@{ kind="list"; listKind="ol"; items=$items })
      }
      elseif ($ln -match '^\s*([*+-])\s+(.*)$') {
        $items = New-Object System.Collections.Generic.List[string]
        while ($i -lt $lines.Count -and $lines[$i].Trim() -match '^\s*([*+-])\s+(.*)$') { $items.Add($Matches[2].Trim()); $i++ }
        $i--; $blocks.Add([pscustomobject]@{ kind="list"; listKind="ul"; items=$items })
      }
      elseif ($ln -match '^>\s?(.*)$') {
        $blocks.Add([pscustomobject]@{ kind="quote"; text=$Matches[1] })
      }
      elseif ($ln -match '^```') {
        $i++; $code = New-Object System.Text.StringBuilder
        while ($i -lt $lines.Count -and ($lines[$i] -notmatch '^```')) { [void]$code.AppendLine($lines[$i]); $i++ }
        $script:HadCode = $true
        $blocks.Add([pscustomobject]@{ kind="code"; text=($code.ToString().TrimEnd()) })
      }
      elseif ($ln -ne "") {
        $blocks.Add([pscustomobject]@{ kind="p"; text=$ln })
      }
      $i++
    }
  }
  return $blocks
}

# --- OneNote XML emit (styles, p, real lists) -----------------------------------
function Get-QuickStyleIndexMap($doc,$nsm) {
  $map = @{}
  $defs = $doc.SelectNodes("//one:QuickStyleDef",$nsm)
  foreach($d in $defs){ $map[$d.GetAttribute("name")] = $d.GetAttribute("index") }
  foreach($name in @("h1","h2","h3","h4","h5","h6","p")){
    if(-not $map.ContainsKey($name)){
      $def = $doc.CreateElement("one:QuickStyleDef",$nsUrl)
      $def.SetAttribute("index",[string]([int]($defs | Measure-Object).Count + 2))
      $def.SetAttribute("name",$name)
      $def.SetAttribute("fontColor","automatic")
      $def.SetAttribute("highlightColor","automatic")
      $def.SetAttribute("font","Calibri")
      $def.SetAttribute("fontSize", $( if($name -eq "p"){"11.0"} elseif($name -eq "h1"){"16.0"} elseif($name -eq "h2"){"14.0"} elseif($name -eq "h3"){"12.0"} else {"11.5"} ))
      $def.SetAttribute("spaceBefore","0.0"); $def.SetAttribute("spaceAfter","0.0")
      $page = $doc.SelectSingleNode("//one:Page",$nsm)
      [void]$page.InsertBefore($def, $page.FirstChild)
      $map[$name] = $def.GetAttribute("index")
    }
  }
  return $map
}

function Add-Paragraph($doc,$nsm,$parentChildren,[string]$text,[string]$styleName,[string]$extraSpanCss="") {
  $oe = $doc.CreateElement("one:OE",$nsUrl)
  $qs = $global:QuickStyles[$styleName]; if(-not $qs){ $qs = $global:QuickStyles["p"] }
  $oe.SetAttribute("alignment","left"); $oe.SetAttribute("quickStyleIndex",$qs)
  $t = $doc.CreateElement("one:T",$nsUrl)
  $encoded = [System.Security.SecurityElement]::Escape($text)
  if([string]::IsNullOrEmpty($extraSpanCss)){
    $t.InnerXml = "<![CDATA[$encoded]]>"
  } else {
    $encodedCss = $extraSpanCss.Replace('"',"'")
    $t.InnerXml = "<![CDATA[<span style='$encodedCss'>$encoded</span>]]>"
  }
  [void]$oe.AppendChild($t)
  [void]$parentChildren.AppendChild($oe)
}

function Add-List($doc,$nsm,$parentChildren,[string]$kind,[System.Collections.Generic.List[string]]$items) {
  $list = $doc.CreateElement("one:List",$nsUrl)
  if ($kind -eq "ol") { $list.SetAttribute("type","Number") } else { $list.SetAttribute("type","Bullet") }
  $lc = $doc.CreateElement("one:OEChildren",$nsUrl); [void]$list.AppendChild($lc)
  foreach($it in $items) { Add-Paragraph -doc $doc -nsm $nsm -parentChildren $lc -text $it -styleName "p" }
  [void]$parentChildren.AppendChild($list)
}

# --- main -----------------------------------------------------------------------
try {
  if ($VerboseLog) { Write-Log "Reading clipboard..." "DEBUG" }
  $frag = Get-CfHtmlFragment
  $text = Get-ClipboardText
  $isHtml = $false; $content = $null
  if ($frag) { $isHtml=$true; $content=$frag } elseif ($text) { $content=$text } else { throw "Clipboard is empty" }

  if ($DiagDump) {
    # clipboard formats (live)
    try {
      Add-Type -AssemblyName System.Windows.Forms
      $obj = [Windows.Forms.Clipboard]::GetDataObject()
      $formats = @()
      if ($obj) { $formats = $obj.GetFormats() } else { $formats = @("<no clipboard>") }
      Write-Json (Join-Path $DiagDir "clipboard.formats.json") $formats
    } catch {}
    if ($isHtml) { Write-File (Join-Path $DiagDir "clipboard.fragment.html") $frag }
    else { Write-File (Join-Path $DiagDir "clipboard.text.txt") $text }
  }

  if ($VerboseLog) { Write-Log "Parsing blocks (isHtml=$isHtml)..." "DEBUG" }
  $blocks = Convert-Blocks -htmlOrText $content -isHtml:$isHtml
  if ($DiagDump) { Write-Json (Join-Path $DiagDir "parsed.blocks.json") $blocks }

  if ($VerboseLog) { Write-Log ("Blocks parsed: " + $blocks.Count) "DEBUG" }

  if ($VerboseLog) { Write-Log "Loading page XML..." "DEBUG" }
  [xml]$doc = Get-Content -LiteralPath $PageXmlPath -Raw
  $nsm = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
  $nsm.AddNamespace("one",$nsUrl)

  if ($DiagDump) { Write-File (Join-Path $DiagDir "page.before.xml") $doc.OuterXml }

  $outline = $doc.SelectSingleNode("//one:Outline[.//one:OE[@selected='all' or @selected='partial']]",$nsm)
  if (-not $outline) { $outline = $doc.SelectSingleNode("//one:Outline",$nsm) }
  if (-not $outline) {
    $outline = $doc.CreateElement("one:Outline",$nsUrl)
    $pos = $doc.CreateElement("one:Position",$nsUrl); $pos.SetAttribute("x","36.0"); $pos.SetAttribute("y","32.0"); $pos.SetAttribute("z","0")
    $size= $doc.CreateElement("one:Size",$nsUrl); $size.SetAttribute("width","500"); $size.SetAttribute("height","13")
    [void]$outline.AppendChild($pos); [void]$outline.AppendChild($size)
    [void]$doc.SelectSingleNode("//one:Page",$nsm).AppendChild($outline)
  }
  $kids = $outline.SelectSingleNode("./one:OEChildren",$nsm)
  if (-not $kids) { $kids = $doc.CreateElement("one:OEChildren",$nsUrl); [void]$outline.AppendChild($kids) }

  $global:QuickStyles = Get-QuickStyleIndexMap -doc $doc -nsm $nsm

  foreach($b in $blocks){
    switch -Regex ($b.kind) {
      "h[1-6]" { Add-Paragraph -doc $doc -nsm $nsm -parentChildren $kids -text $b.text -styleName $b.kind }
      "code"   {
        $script:HadCode = $true
        Add-Paragraph -doc $doc -nsm $nsm -parentChildren $kids -text $b.text -styleName "p" `
          -extraSpanCss "font-family:Consolas,'Courier New',monospace;background:#f5f5f5;padding:0 2px;border:1px solid #eee;border-radius:3px"
      }
      "quote"  { Add-Paragraph -doc $doc -nsm $nsm -parentChildren $kids -text $b.text -styleName "p" `
          -extraSpanCss "font-style:italic;color:#6d6d6d" }
      "list"   { Add-List -doc $doc -nsm $nsm -parentChildren $kids -kind $b.listKind -items $b.items }
      default  { Add-Paragraph -doc $doc -nsm $nsm -parentChildren $kids -text $b.text -styleName "p" }
    }
  }

  # Optional sentinel you can search for in a macro if you want conditional Colorize later:
  # if ($HadCode) { Append-Paragraph -doc $doc -nsm $nsm -parentChildren $kids -text "[HAS_CODE_SENTINEL]" -styleName "p" }

  $doc.Save($PageXmlPath)

  if ($DiagDump) { Write-File (Join-Path $DiagDir "page.after.xml") $doc.OuterXml }

  Write-Log ("Done in {0} ms. HadCode={1}" -f $sw.ElapsedMilliseconds, $HadCode) "INFO"
}
catch {
  Write-Log ("ERROR: " + $_.Exception.Message) "ERROR"
  Write-Log ("STACK: " + $_.ScriptStackTrace) "ERROR"
  throw
}
finally {
  try { if ($VerboseLog) { Stop-Transcript | Out-Null } } catch {}
}
