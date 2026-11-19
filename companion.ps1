# Dragon's Dogma 2 Trainer by RipXic - Claude companion  v1.0
# Optional add-on for the trainer. It runs in its own window next to the game and does two things a REFramework Lua
# mod cannot do by itself:
#   * save backups: copies your Steam save folder before the trainer changes something that is saved with your game
#   * "Ask Claude":  answers the questions you type on the trainer's Ask Claude page, using the Claude Code that comes
#                    with the Claude desktop app (your own Claude account / plan)
#
# How the trainer and the companion talk - plain files in <game>\reframework\data\wf_companion\ :
#   req\<id>.json   written by the trainer   { id, kind = "backup" | "ask", label, question, context }
#   ans\<id>.json   written here             { id, ok, text, lua, error }
#   status.json     written here every 2 s   (the trainer shows "companion running")
#
# Claude runs with NO tools, no MCP servers, no saved session and a budget cap per question: it only reads the
# question + the game snapshot the trainer sends and writes an answer. A suggested settings change is only run in the
# game after you click "Do it" on the trainer page (and it goes into the trainer's Undo list).
#
# Start: double-click start_companion.bat. Close the window (or Ctrl+C) to stop.
# Options (all optional), e.g.  start_companion.bat -Game "D:\Games\Dragons Dogma 2" -Keep 20
param(
    [string]$Game = '',                      # game folder; empty = found through Steam
    [string]$BackupRoot = '',                # empty = Documents\DD2 Trainer save backups
    [int]$Keep = 40,                         # newest backups kept
    [string]$Model = 'claude-sonnet-5-5',    # Claude model for Ask Claude
    [double]$BudgetUsd = 0.5,                # spending cap per question
    [int]$AskTimeoutSec = 180
)
$ErrorActionPreference = 'Continue'
$Version = '1.0'
$AppId = '2054970'                           # Dragon's Dogma 2 on Steam
$Here = $PSScriptRoot

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

# ---------------------------------------------------------------- Steam / game / saves
function Find-Steam {
    foreach ($k in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam') {
        $p = (Get-ItemProperty $k -ErrorAction SilentlyContinue)
        foreach ($v in @($p.SteamPath, $p.InstallPath)) { if ($v -and (Test-Path $v)) { return ($v -replace '/', '\') } }
    }
    $d = Join-Path ${env:ProgramFiles(x86)} 'Steam'
    if (Test-Path $d) { return $d }
    return $null
}
function Find-Game($steam) {
    if (-not $steam) { return $null }
    $libs = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += ($m.Groups[1].Value -replace '\\\\', '\') }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $acf = Join-Path $lib "steamapps\appmanifest_$AppId.acf"
        $dir = 'Dragons Dogma 2'
        if (Test-Path $acf) { $m = [regex]::Match((Get-Content $acf -Raw), '"installdir"\s+"([^"]+)"'); if ($m.Success) { $dir = $m.Groups[1].Value } }
        $g = Join-Path $lib "steamapps\common\$dir"
        if (Test-Path (Join-Path $g 'DD2.exe')) { return $g }
    }
    return $null
}
function Find-SaveDir($steam) {
    if (-not $steam) { return $null }
    # several Steam accounts on one PC: the save folder written most recently
    $d = Get-ChildItem (Join-Path $steam "userdata\*\$AppId\remote\win64_save") -Directory -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($d) { return $d.FullName } else { return $null }
}
function Find-Claude {
    $c = Get-ChildItem (Join-Path $env:APPDATA 'Claude\claude-code') -Recurse -Filter 'claude.exe' -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($c) { return $c.FullName }
    $g = Get-Command claude -ErrorAction SilentlyContinue
    if ($g) { return $g.Source }
    return $null
}

$Steam = Find-Steam
if (-not $Game) { $Game = Find-Game $Steam }
if (-not $Game -or -not (Test-Path $Game)) {
    Say "Dragon's Dogma 2 was not found. Start it like this with your game folder:" Red
    Say '  start_companion.bat -Game "D:\Path\To\Dragons Dogma 2"' Yellow
    exit 1
}
if (-not (Test-Path (Join-Path $Game 'reframework\autorun\wildframe_dd2_panel.lua'))) {
    Say "Warning: the trainer was not found in $Game\reframework\autorun - install REFramework and the trainer first." Yellow
}
if (-not $BackupRoot) { $BackupRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'DD2 Trainer save backups' }
$Data = Join-Path $Game 'reframework\data\wf_companion'
$ReqDir = Join-Path $Data 'req'; $AnsDir = Join-Path $Data 'ans'
New-Item -ItemType Directory -Force $ReqDir, $AnsDir, $BackupRoot | Out-Null
$Claude = Find-Claude
$SaveDir = Find-SaveDir $Steam
$SystemFile = Join-Path $Here 'system_prompt.txt'

$Host.UI.RawUI.WindowTitle = "DD2 Trainer - Claude companion $Version"
Say "Dragon's Dogma 2 Trainer by RipXic - Claude companion $Version" Cyan
Say "  game     : $Game"
Say "  saves    : $(if ($SaveDir) { $SaveDir } else { 'NOT FOUND - backups are off' })"
Say "  backups  : $BackupRoot (newest $Keep kept)"
Say "  claude   : $(if ($Claude) { $Claude } else { 'NOT FOUND - Ask Claude is off (install the Claude desktop app and sign in)' })"
if (-not (Test-Path $SystemFile)) { Say "  system_prompt.txt is missing next to companion.ps1 - Ask Claude is off" Yellow }
Say "Keep this window open while you play. Close it to stop." DarkGray

function Write-Json($path, $obj) {
    $tmp = "$path.tmp"
    [IO.File]::WriteAllText($tmp, ($obj | ConvertTo-Json -Depth 6 -Compress), (New-Object Text.UTF8Encoding $false))
    Move-Item $tmp $path -Force
}
$script:lastBackup = $null; $script:asks = 0; $script:backups = 0
function Write-Status {
    # clock = UTC unix seconds (the trainer compares it with os.time to see the companion is alive)
    Write-Json (Join-Path $Data 'status.json') @{ running = $true; version = $Version; time = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss');
        clock = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); claude = [bool]($Claude -and (Test-Path $SystemFile)); saves = [bool]$SaveDir;
        backups = $script:backups; asks = $script:asks; last_backup = $script:lastBackup }
}

# ---------------------------------------------------------------- save backups
function Do-Backup($req) {
    if (-not $SaveDir) { return @{ ok = $false; error = 'save folder not found' } }
    $label = ([string]$req.label -replace '[^\w\- ]', '').Trim(); if (-not $label) { $label = 'panel' }
    $name = (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + $label.Substring(0, [Math]::Min(40, $label.Length))
    Copy-Item $SaveDir (Join-Path $BackupRoot $name) -Recurse -Force
    $all = Get-ChildItem $BackupRoot -Directory | Sort-Object Name
    if ($all.Count -gt $Keep) { $all | Select-Object -First ($all.Count - $Keep) | ForEach-Object { Remove-Item $_.FullName -Recurse -Force } }
    $script:lastBackup = $name; $script:backups++
    Say "backup  $name" Green
    return @{ ok = $true; text = "save backed up: $name" }
}

# ---------------------------------------------------------------- Ask Claude
function Do-Ask($req) {
    if (-not $Claude) { return @{ ok = $false; error = 'Claude Code was not found - install the Claude desktop app and sign in' } }
    if (-not (Test-Path $SystemFile)) { return @{ ok = $false; error = 'system_prompt.txt is missing next to companion.ps1' } }
    $prompt = "Player's question:`n$($req.question)`n`nLive game + panel snapshot (JSON):`n$($req.context | ConvertTo-Json -Depth 6 -Compress)"
    $job = Start-Job -ScriptBlock {
        param($exe, $p, $sysfile, $model, $budget)
        # the answer is UTF-8; without this, characters like arrows come back garbled
        [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false; $OutputEncoding = New-Object Text.UTF8Encoding $false
        # '""' : Windows PowerShell 5.1 drops a plain "" argument; this reaches claude.exe as an empty value = no tools.
        # The system prompt goes in as a FILE: PS 5.1 breaks double quotes inside long arguments to programs.
        $p | & $exe -p --output-format json --tools '""' --strict-mcp-config --no-session-persistence `
            --model $model --max-budget-usd $budget --system-prompt-file $sysfile 2>&1
    } -ArgumentList $Claude, $prompt, $SystemFile, $Model, $BudgetUsd
    if (-not (Wait-Job $job -Timeout $AskTimeoutSec)) { Stop-Job $job; Remove-Job $job -Force; return @{ ok = $false; error = "no answer after $AskTimeoutSec s" } }
    $out = (Receive-Job $job | Out-String); Remove-Job $job -Force
    $script:asks++
    try { $j = $out | ConvertFrom-Json } catch { return @{ ok = $false; error = 'could not read the answer: ' + $out.Substring(0, [Math]::Min(300, $out.Length)) } }
    if ($j.is_error) { return @{ ok = $false; error = [string]$j.result } }
    $text = [string]$j.result
    $lua = $null
    $m = [regex]::Match($text, '```lua\s*\r?\n(.*?)```', 'Singleline')
    if ($m.Success) { $lua = $m.Groups[1].Value.Trim(); $text = $text.Replace($m.Value, '').Trim() }
    # only code whose every line uses wf. (or is the final return / a comment) is offered to the trainer
    if ($lua) {
        $bad = @($lua -split "`r?`n" | Where-Object { $_.Trim() -ne '' -and $_.Trim() -notmatch '^(--|return\b|end\b|else\b)' -and $_ -notmatch '\bwf\.' })
        if ($bad.Count -gt 0) { $lua = $null; $text += "`n`n(The suggested change was not in a form the trainer can run, so it was left out - change it on the trainer page instead.)" }
        elseif ($lua -notmatch '\breturn\b') { $lua += "`nreturn ""done""" }
    }
    $q = [string]$req.question
    Say "ask     $($q.Substring(0, [Math]::Min(60, $q.Length)))  -> $(if ($lua) { 'answer + change' } else { 'answer' })" Green
    return @{ ok = $true; text = $text; lua = $lua; cost = $j.total_cost_usd }
}

# ---------------------------------------------------------------- main loop
Write-Status
$lastStatus = Get-Date
while ($true) {
    foreach ($f in (Get-ChildItem $ReqDir -Filter '*.json' -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $req = $null
        try { $req = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { Start-Sleep -Milliseconds 200; continue }   # still being written
        Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
        if (-not $req.id) { continue }
        $res = switch ($req.kind) { 'backup' { Do-Backup $req } 'ask' { Do-Ask $req } default { @{ ok = $false; error = "unknown request $($req.kind)" } } }
        $res.id = $req.id
        Write-Json (Join-Path $AnsDir "$($req.id).json") $res
        Get-ChildItem $AnsDir -Filter '*.json' | Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-1) } | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    if (((Get-Date) - $lastStatus).TotalSeconds -ge 2) { Write-Status; $lastStatus = Get-Date }
    Start-Sleep -Milliseconds 500
}
