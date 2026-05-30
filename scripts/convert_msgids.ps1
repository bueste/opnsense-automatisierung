# Convert German msgids to English msgids throughout the plugin.
# Reads the mapping from en_US.po (German→English), then:
#  - Rewrites all lang._('German') → lang._('English') in volt/php files
#  - Rewrites de_DE.po  → msgid=English, msgstr=German
#  - Rewrites en_US.po  → msgid=English, msgstr="" (English is now the source)
#  - Rewrites all other .po files → msgid=English, msgstr=existing (may be empty)

param(
    [string]$Root = "$PSScriptRoot\.."
)

$ErrorActionPreference = "Stop"
$src = Join-Path $Root "src\opnsense\mvc\app"
$locale = Join-Path $src "locale"

# ── 1. Parse en_US.po → @{German = English} ──────────────────────────────────
$poFile = Join-Path $locale "en_US\LC_MESSAGES\OPNsense.Automatisierung.po"
$poRaw  = [System.IO.File]::ReadAllText($poFile, [System.Text.Encoding]::UTF8)

# Split into blocks by blank lines, collect msgid/msgstr pairs
$map = [ordered]@{}    # German → English
$revMap = [ordered]@{} # German → German (for langs that only have empty msgstr)

$blocks = $poRaw -split "\n\n"
foreach ($block in $blocks) {
    if ($block -notmatch 'msgid\s+"(.+)"' ) { continue }
    $german = $Matches[1]
    $english = ""
    if ($block -match 'msgstr\s+"(.*)"') {
        $english = $Matches[1]
    }
    if ($german -ne "" -and $english -ne "" -and $german -ne $english) {
        $map[$german] = $english
    }
}

Write-Host "Loaded $($map.Count) German→English mappings from en_US.po"

# ── 2. Replace lang._('German') in volt / php files ──────────────────────────
$files = @(
    (Join-Path $src "views\OPNsense\Automatisierung\config.volt"),
    (Join-Path $src "views\OPNsense\Automatisierung\status.volt"),
    (Join-Path $src "views\OPNsense\Automatisierung\backup.volt"),
    (Join-Path $src "controllers\OPNsense\Automatisierung\IndexController.php")
)

foreach ($f in $files) {
    $content = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
    $before  = $content
    foreach ($ger in $map.Keys) {
        $eng = $map[$ger]
        # lang._('German') → lang._('English')
        $content = $content.Replace("lang._('$ger')", "lang._('$eng')")
        # lang._("German") → lang._("English")
        $content = $content.Replace('lang._("' + $ger + '")', 'lang._("' + $eng + '")')
        # gettext('German') → gettext('English')
        $content = $content.Replace("gettext('$ger')", "gettext('$eng')")
        # gettext("German") → gettext("English")
        $content = $content.Replace('gettext("' + $ger + '")', 'gettext("' + $eng + '")')
    }
    if ($content -ne $before) {
        [System.IO.File]::WriteAllText($f, $content, [System.Text.Encoding]::UTF8)
        Write-Host "Updated: $(Split-Path $f -Leaf)"
    } else {
        Write-Host "No changes: $(Split-Path $f -Leaf)"
    }
}

# ── 3. Rewrite each .po file ──────────────────────────────────────────────────
function Rewrite-PO {
    param([string]$Path, [hashtable]$IdMap, [string]$LangLabel)

    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)

    # Preserve header block (everything before first real msgid/msgstr pair)
    $headerEnd = $raw.IndexOf("`nmsgid `"")
    if ($headerEnd -lt 0) { $headerEnd = $raw.IndexOf("`r`nmsgid `"") }
    $header = $raw.Substring(0, $headerEnd + 1)

    # Update Language-Team in header
    $header = $header -replace 'Language-Team:.*', "Language-Team: $LangLabel"

    # Parse all (msgid, msgstr) pairs that follow
    $pairs = [System.Collections.Generic.List[object]]::new()
    $rx = [regex]::new('msgid "([^"]*(?:\\.[^"]*)*)"\s+msgstr "([^"]*(?:\\.[^"]*)*)"',
                        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    foreach ($m in $rx.Matches($raw)) {
        $pairs.Add([pscustomobject]@{
            OrigId  = $m.Groups[1].Value
            OrigStr = $m.Groups[2].Value
        })
    }

    $sb = [System.Text.StringBuilder]::new()
    $sb.Append($header) | Out-Null

    foreach ($pair in $pairs) {
        $origId  = $pair.OrigId
        $origStr = $pair.OrigStr

        if ($origId -eq "") {
            # Skip the header msgid block (already handled above)
            continue
        }

        # If this German msgid has an English translation, use English as new msgid
        if ($IdMap.Contains($origId)) {
            $newId  = $IdMap[$origId]   # English
            $newStr = $origStr          # Whatever the current translation was
        } else {
            # String that is already English or same in both languages
            $newId  = $origId
            $newStr = $origStr
        }

        $sb.AppendLine("") | Out-Null
        $sb.AppendLine("msgid `"$newId`"") | Out-Null
        $sb.AppendLine("msgstr `"$newStr`"") | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $sb.ToString(), [System.Text.Encoding]::UTF8)
    Write-Host "Rewrote PO: $Path"
}

# en_US: msgid=English, msgstr="" (it IS English, no translation needed)
$enUsMap = [ordered]@{}
foreach ($ger in $map.Keys) { $enUsMap[$ger] = $map[$ger] }  # German→English

# We need a special version of en_US: English msgid, empty msgstr
# (the mapping gives us German→English; after replacement msgstr should be empty)
function Rewrite-EnUS {
    param([string]$Path, [hashtable]$IdMap)

    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $headerEnd = $raw.IndexOf("`nmsgid `"")
    if ($headerEnd -lt 0) { $headerEnd = $raw.IndexOf("`r`nmsgid `"") }
    $header = $raw.Substring(0, $headerEnd + 1)

    $pairs = [System.Collections.Generic.List[object]]::new()
    $rx = [regex]::new('msgid "([^"]*(?:\\.[^"]*)*)"\s+msgstr "([^"]*(?:\\.[^"]*)*)"',
                        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    foreach ($m in $rx.Matches($raw)) {
        $pairs.Add([pscustomobject]@{
            OrigId  = $m.Groups[1].Value
            OrigStr = $m.Groups[2].Value
        })
    }

    $sb = [System.Text.StringBuilder]::new()
    $sb.Append($header) | Out-Null

    foreach ($pair in $pairs) {
        $origId  = $pair.OrigId
        if ($origId -eq "") { continue }

        # German → English msgid, empty msgstr (English is the source)
        if ($IdMap.Contains($origId)) {
            $newId  = $IdMap[$origId]
            $newStr = ""
        } else {
            $newId  = $origId
            $newStr = ""
        }

        $sb.AppendLine("") | Out-Null
        $sb.AppendLine("msgid `"$newId`"") | Out-Null
        $sb.AppendLine("msgstr `"$newStr`"") | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $sb.ToString(), [System.Text.Encoding]::UTF8)
    Write-Host "Rewrote en_US PO: $Path"
}

# de_DE: msgid=English, msgstr=German (the German string was the msgid, now becomes msgstr)
function Rewrite-DeDE {
    param([string]$Path, [hashtable]$IdMap)

    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $headerEnd = $raw.IndexOf("`nmsgid `"")
    if ($headerEnd -lt 0) { $headerEnd = $raw.IndexOf("`r`nmsgid `"") }
    $header = $raw.Substring(0, $headerEnd + 1)

    $pairs = [System.Collections.Generic.List[object]]::new()
    $rx = [regex]::new('msgid "([^"]*(?:\\.[^"]*)*)"\s+msgstr "([^"]*(?:\\.[^"]*)*)"',
                        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    foreach ($m in $rx.Matches($raw)) {
        $pairs.Add([pscustomobject]@{
            OrigId  = $m.Groups[1].Value   # German
            OrigStr = $m.Groups[2].Value   # Empty (was the de_DE PO)
        })
    }

    $sb = [System.Text.StringBuilder]::new()
    $sb.Append($header) | Out-Null

    foreach ($pair in $pairs) {
        $origId  = $pair.OrigId   # German string
        if ($origId -eq "") { continue }

        if ($IdMap.Contains($origId)) {
            $newId  = $IdMap[$origId]   # English becomes msgid
            $newStr = $origId           # German becomes msgstr
        } else {
            $newId  = $origId
            $newStr = $pair.OrigStr
        }

        $sb.AppendLine("") | Out-Null
        $sb.AppendLine("msgid `"$newId`"") | Out-Null
        $sb.AppendLine("msgstr `"$newStr`"") | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $sb.ToString(), [System.Text.Encoding]::UTF8)
    Write-Host "Rewrote de_DE PO: $Path"
}

# Other locales: msgid=English (was German), msgstr=existing translation (may be empty)
function Rewrite-OtherPO {
    param([string]$Path, [hashtable]$IdMap, [string]$LangLabel)

    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $headerEnd = $raw.IndexOf("`nmsgid `"")
    if ($headerEnd -lt 0) { $headerEnd = $raw.IndexOf("`r`nmsgid `"") }
    $header = $raw.Substring(0, $headerEnd + 1)

    $pairs = [System.Collections.Generic.List[object]]::new()
    $rx = [regex]::new('msgid "([^"]*(?:\\.[^"]*)*)"\s+msgstr "([^"]*(?:\\.[^"]*)*)"',
                        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    foreach ($m in $rx.Matches($raw)) {
        $pairs.Add([pscustomobject]@{
            OrigId  = $m.Groups[1].Value
            OrigStr = $m.Groups[2].Value
        })
    }

    $sb = [System.Text.StringBuilder]::new()
    $sb.Append($header) | Out-Null

    foreach ($pair in $pairs) {
        $origId  = $pair.OrigId
        if ($origId -eq "") { continue }

        if ($IdMap.Contains($origId)) {
            $newId  = $IdMap[$origId]
        } else {
            $newId  = $origId
        }
        $newStr = $pair.OrigStr

        $sb.AppendLine("") | Out-Null
        $sb.AppendLine("msgid `"$newId`"") | Out-Null
        $sb.AppendLine("msgstr `"$newStr`"") | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $sb.ToString(), [System.Text.Encoding]::UTF8)
    Write-Host "Rewrote PO [$LangLabel]: $Path"
}

# Convert the ordered hashtable to a plain hashtable for Contains()
$hashMap = @{}
foreach ($k in $map.Keys) { $hashMap[$k] = $map[$k] }

Rewrite-EnUS (Join-Path $locale "en_US\LC_MESSAGES\OPNsense.Automatisierung.po") $hashMap
Rewrite-DeDE (Join-Path $locale "de_DE\LC_MESSAGES\OPNsense.Automatisierung.po") $hashMap

foreach ($lang in @("fr_FR","it_IT","es_ES","pt_BR","nl_NL","ru_RU","cs_CZ","pl_PL","tr_TR","zh_CN","ja_JP","ko_KR")) {
    $path = Join-Path $locale "$lang\LC_MESSAGES\OPNsense.Automatisierung.po"
    if (Test-Path $path) {
        Rewrite-OtherPO $path $hashMap $lang
    }
}

Write-Host ""
Write-Host "Done. Compile .mo files on the firewall with:"
Write-Host "  for f in /usr/local/opnsense/mvc/app/locale/*/LC_MESSAGES/OPNsense.Automatisierung.po; do msgfmt -o `${f%.po}.mo` `$f; done"
