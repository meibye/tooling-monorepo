# MarkdownToOneNote.ps1
# OneMore Plugin: Markdown → formatted OneNote HTML
# Now with: headings, bold/italic/underline/strike, links, inline code, fenced code blocks,
# nested lists (unordered/ordered), *multi-paragraph list items*, and *tables* with alignment.
#
# Place in: %AppData%\OneMoreAddIn\Plugins
# OneNote → OneMore → Settings → Plugins → Reload Plugins

PluginInfo @{
    Name        = "Markdown → OneNote (Headings/Lists/Code/Tables)"
    Description = "Converts selected Markdown to formatted OneNote (headings, lists incl. multi-paragraph items, fenced & inline code, tables)"
    Author      = "Michael"
    Version     = "1.2"
    Menu        = "Plugins"
    Shortcut    = "Ctrl+Shift+B"
}

param($page, $selection)

# ---------------- Helpers ----------------

function Escape-Html {
    param([string]$s)
    if ([string]::IsNullOrEmpty($s)) { return "" }
    $s = $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;')
    return $s
}

# ---------- INLINE CODE (`code`) ----------
$global:CodeStash = @{}
$global:CodeCounter = 0
function Stash-InlineCode {
    param([string]$text)
    $global:CodeStash.Clear()
    $global:CodeCounter = 0
    return [regex]::Replace($text, '(`+)([\s\S]*?)(?<!`)\1', {
        param($m)
        $ticks = $m.Groups[1].Value
        $code  = $m.Groups[2].Value
        $global:CodeCounter++
        $key = "__CODE_STASH_$($global:CodeCounter)__"
        $esc = Escape-Html $code
        $global:CodeStash[$key] = "<code>$esc</code>"
        return $key
    }, 'Singleline')
}
function Unstash-InlineCode {
    param([string]$text)
    foreach ($k in $global:CodeStash.Keys) { $text = $text.Replace($k, $global:CodeStash[$k]) }
    return $text
}

# ---------- FENCED CODE (```lang ... ```) ----------
$global:FencedStash = @{}
$global:FencedCounter = 0
function Stash-FencedCode {
    param([string]$text)
    # Matches ```lang\n ... \n```  (lang optional)
    return [regex]::Replace($text, '(^|\n)```([A-Za-z0-9\-\_]+)?\r?\n([\s\S]*?)\r?\n```', {
        param($m)
        $leading = $m.Groups[1].Value
        $lang    = $m.Groups[2].Value
        $code    = $m.Groups[3].Value

        $global:FencedCounter++
        $key = "__FENCED_CODE_STASH_$($global:FencedCounter)__"

        $esc = Escape-Html $code
        $html = [string]::IsNullOrEmpty($lang) ? "<pre><code>$esc</code></pre>" : "<pre><code class=""language-$lang"">$esc</code></pre>"
        $global:FencedStash[$key] = $html
        return $leading + $key
    }, 'Singleline')
}
function Unstash-FencedCode {
    param([string]$text)
    foreach ($k in $global:FencedStash.Keys) { $text = $text.Replace($k, $global:FencedStash[$k]) }
    return $text
}

# ---------- INLINE STYLES ----------
function Convert-Inline {
    param([string]$t)

    # Links: [text](url)
    $t = [regex]::Replace($t, '\[([^\]]+)\]\(([^\s\)]+)\)', {
        param($m)
        $label = Escape-Html $m.Groups[1].Value
        $url   = $m.Groups[2].Value
        if ($url -notmatch '^(https?|mailto):') { $url = 'https://' + $url }
        return "<a href=""$url"">$label</a>"
    })

    # Bold
    $t = [regex]::Replace($t, '(?<!\*)\*\*(.+?)\*\*(?!\*)', '<b>$1</b>')
    $t = [regex]::Replace($t, '(?<!_)__(.+?)__(?!_)', '<b>$1</b>')

    # Italic
    $t = [regex]::Replace($t, '(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)', '<i>$1</i>')
    $t = [regex]::Replace($t, '(?<!_)_(?!_)(.+?)(?<!_)_(?!_)', '<i>$1</i>')

    # Underline (convenience)
    $t = [regex]::Replace($t, '\b__([^\s][\s\S]*?[^\s])__\b', '<u>$1</u>')

    # Strikethrough
    $t = [regex]::Replace($t, '~~(.+?)~~', '<s>$1</s>')

    return $t
}

# ---------- HEADINGS (# .. ######) ----------
function Convert-Headings {
    param([string]$text)
    $lines = $text -split "`r?`n"
    for ($i=0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $m = [regex]::Match($line, '^\s{0,3}(#{1,6})\s+(.*)$')
        if ($m.Success) {
            $level = $m.Groups[1].Value.Length
            $body  = Escape-Html $m.Groups[2].Value
            $lines[$i] = "<h$level>$body</h$level>"
        }
    }
    return ($lines -join "`n")
}

# ---------- TABLES ----------
$global:TableStash = @{}
$global:TableCounter = 0

function TryParse-AlignmentRow {
    param([string]$row)
    # Accept forms like: | :--- | :--: | ---: | --- |
    $cells = ($row.Trim() -replace '^\|','' -replace '\|$','').Split('|')
    $align = @()
    foreach ($c in $cells) {
        $t = $c.Trim()
        if ($t -match '^:?-{3,}:?$') {
            if ($t.StartsWith(':') -and $t.EndsWith(':')) { $align += 'center' }
            elseif ($t.EndsWith(':')) { $align += 'right' }
            elseif ($t.StartsWith(':')) { $align += 'left' }
            else { $align += 'left' }
        } else {
            return $null
        }
    }
    return ,$align  # return array
}

function Is-PipeRow {
    param([string]$line)
    # A "table-y" row: contains at least one pipe and some non-pipe text
    return ($line -match '\|' -and $line.Trim().Length -gt 1)
}

function Stash-Tables {
    param([string]$text)

    $lines = $text -split "`r?`n"
    $i = 0
    $out = New-Object System.Text.StringBuilder

    while ($i -lt $lines.Count) {
        # Look for a table header row followed by alignment row
        if (Is-PipeRow $lines[$i] -and ($i + 1) -lt $lines.Count -and (TryParse-AlignmentRow $lines[$i+1])) {
            $headerLine = $lines[$i]
            $alignRow   = $lines[$i+1]
            $i += 2

            # Collect body rows while they are "pipe rows"
            $body = @()
            while ($i -lt $lines.Count -and (Is-PipeRow $lines[$i])) {
                $body += $lines[$i]
                $i++
            }

            # Build table HTML
            $global:TableCounter++
            $key = "__TABLE_STASH_$($global:TableCounter)__"

            $headers = ($headerLine.Trim() -replace '^\|','' -replace '\|$','').Split('|') | ForEach-Object { $_.Trim() }
            $align = TryParse-AlignmentRow $alignRow

            $thead = "<thead><tr>" + (
                for ($c=0; $c -lt $headers.Count; $c++) {
                    $h = Escape-Html $headers[$c]
                    $a = if ($c -lt $align.Count) { $align[$c] } else { 'left' }
                    "<th style=""text-align:$a"">$h</th>"
                }
            ) -join '' + "</tr></thead>"

            $tbodyRows = @()
            foreach ($r in $body) {
                $cells = ($r.Trim() -replace '^\|','' -replace '\|$','').Split('|')
                $tds = for ($c=0; $c -lt [math]::Max($cells.Count, $headers.Count); $c++) {
                    $val = if ($c -lt $cells.Count) { Escape-Html ($cells[$c].Trim()) } else { "" }
                    $a = if ($c -lt $align.Count) { $align[$c] } else { 'left' }
                    "<td style=""text-align:$a"">$val</td>"
                }
                $tbodyRows += "<tr>" + ($tds -join '') + "</tr>"
            }
            $tbody = "<tbody>" + ($tbodyRows -join '') + "</tbody>"

            $tableHtml = "<table>" + $thead + $tbody + "</table>"
            $global:TableStash[$key] = $tableHtml
            [void]$out.AppendLine($key)
            continue
        }

        # Not a table: pass through
        [void]$out.AppendLine($lines[$i])
        $i++
    }

    return $out.ToString().TrimEnd("`r","`n")
}

function Unstash-Tables {
    param([string]$text)
    foreach ($k in $global:TableStash.Keys) { $text = $text.Replace($k, $global:TableStash[$k]) }
    return $text
}

# ---------- LISTS with multi-paragraph items ----------
function Convert-Lists {
    param([string]$text)

    $lines = $text -split "`r?`n"
    $sb = New-Object System.Text.StringBuilder
    $stack = New-Object System.Collections.Stack # items: @{ level=int; type='ul'|'ol' }

    function Close-ItemsToLevel([int]$target) {
        while ($stack.Count -gt $target) {
            $top = $stack.Pop()
            [void]$sb.AppendLine("</li>")
            [void]$sb.AppendLine("</$($top.type)>")
        }
    }

    function Open-List([string]$type) {
        [void]$sb.AppendLine("<$type>")
        $stack.Push(@{ level = $stack.Count; type = $type; openItem = $false })
    }

    function Ensure-NewItem([string]$type) {
        if ($stack.Count -eq 0 -or $stack.Peek().type -ne $type) {
            if ($stack.Count -gt 0) {
                [void]$sb.AppendLine("</li>")
                $top = $stack.Pop()
                [void]$sb.AppendLine("</$($top.type)>")
            }
            Open-List $type
        } else {
            # same type and level: close previous item if open
            $top = $stack.Pop()
            if ($top.openItem) { [void]$sb.AppendLine("</li>") }
            $top.openItem = $false
            $stack.Push($top)
        }
        [void]$sb.AppendLine("<li>")
        # mark openItem
        $top = $stack.Pop()
        $top.openItem = $true
        $stack.Push($top)
    }

    function CurrentLevel() { return $stack.Count }

    # Patterns
    $reItem = '^(?<indent>\s*)(?:(?<num>\d+)\.\s+|(?<bul>[\-\*\+])\s+)(?<text>.+)$'
    $reBlank = '^\s*$'

    for ($i=0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Keep block placeholders/headings/tables intact
        if ($line -match '__FENCED_CODE_STASH_\d+__' -or $line -match '__TABLE_STASH_\d+__' -or $line -match '^\s*<h[1-6]>') {
            Close-ItemsToLevel 0
            [void]$sb.AppendLine($line)
            continue
        }

        $m = [regex]::Match($line, $reItem)
        if ($m.Success) {
            $indent = $m.Groups['indent'].Value.Length
            $level  = [math]::Floor($indent / 2)   # 2+ spaces per level
            $isOrdered = $m.Groups['num'].Success
            $type   = $isOrdered ? 'ol' : 'ul'
            $textPart = $m.Groups['text'].Value

            # Adjust open lists to desired nesting
            if ($level -gt $stack.Count) {
                while ($stack.Count -lt $level) { Open-List $type }
                Ensure-NewItem $type
            } elseif ($level -lt $stack.Count) {
                Close-ItemsToLevel $level
                Ensure-NewItem $type
            } else {
                # same level
                Ensure-NewItem $type
            }

            $esc = Escape-Html $textPart
            [void]$sb.AppendLine("<p>$esc</p>")
            continue
        }

        # Continuation or blank line inside a list item -> becomes paragraph in same <li>
        if ($stack.Count -gt 0) {
            if ($line -match $reBlank) {
                # Blank line marks paragraph break within current list item
                [void]$sb.AppendLine("") # just a break; next non-blank creates a new <p>
                continue
            } else {
                # Treat as continuation paragraph inside current <li> if sufficiently indented OR plain follow-up
                $esc = Escape-Html $line.Trim()
                [void]$sb.AppendLine("<p>$esc</p>")
                continue
            }
        }

        # Outside lists: pass through
        [void]$sb.AppendLine($line)
    }

    Close-ItemsToLevel 0
    return $sb.ToString().TrimEnd("`r","`n")
}

# ---------- Paragraph wrapping ----------
function Wrap-Paragraphs {
    param([string]$text)
    $lines = $text -split "`r?`n"
    for ($i=0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { $lines[$i] = "<br>"; continue }
        if ($line -match '^\s*<(h[1-6]|ul|ol|li|/ul|/ol|/li|pre|/pre|table|/table|thead|/thead|tbody|/tbody|tr|/tr|td|/td|th|/th)') { continue }
        if ($line -match '__FENCED_CODE_STASH_\d+__' -or $line -match '__TABLE_STASH_\d+__') { continue }
        $lines[$i] = "<div>$line</div>"
    }
    return ($lines -join "`n")
}

# ---------------- Main ----------------

$raw = $selection.Text
if ([string]::IsNullOrWhiteSpace($raw)) {
    $selection.InsertHtml("<i>(Select some Markdown text and run the plugin again.)</i>", $true)
    return
}

# 1) Fenced code → stash
$stageFenced = Stash-FencedCode -text $raw

# 2) Inline code → stash
$stage0 = Stash-InlineCode -text $stageFenced

# 3) Headings
$stage1 = Convert-Headings -text $stage0

# 4) Tables → stash (works on raw lines; we will escape non-table lines later)
$stageTables = Stash-Tables -text $stage1

# 5) Escape non-heading/non-placeholder lines (to keep HTML safe)
$lines = $stageTables -split "`r?`n"
for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*<h[1-6]>' -or $lines[$i] -match '__FENCED_CODE_STASH_\d+__' -or $lines[$i] -match '__TABLE_STASH_\d+__') { continue }
    $lines[$i] = Escape-Html $lines[$i]
}
$stage2 = ($lines -join "`n")

# 6) Lists (supports multi-paragraph items)
$stage3 = Convert-Lists -text $stage2

# 7) Inline (bold/italic/underline/strike/links)
$stage4 = Convert-Inline -t $stage3

# 8) Restore inline code spans
$stage5 = Unstash-InlineCode -text $stage4

# 9) Wrap remaining lines into blocks
$stage6 = Wrap-Paragraphs -text $stage5

# 10) Restore tables and fenced code blocks
$stage7 = Unstash-Tables -text $stage6
$html   = Unstash-FencedCode -text $stage7

# 11) Output to OneNote (replace selection)
$selection.InsertHtml($html, $true)
