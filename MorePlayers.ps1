# Medieval Dynasty - More Players
# Raises the co-op player cap (default 4) for the HOST. Joining players need nothing.
#
# Usage (normally via the .bat files):
#   MorePlayers.ps1 -Players 8        set the cap to 8 (2-64)
#   MorePlayers.ps1 -Status           show the current cap
#   MorePlayers.ps1 -Uninstall        restore the original game (cap 4)
#   -GameDir "<path>"                 game folder, if it can't be found automatically
#
# It changes two things:
#   1. Medieval_Dynasty-Win64-Shipping.exe : the lobby size the game creates when you host (7 bytes)
#   2. %LOCALAPPDATA%\Medieval_Dynasty\Saved\Config\WindowsNoEditor\Game.ini :
#        [/Script/Engine.GameSession] MaxPlayers=<n>   (the host's join limit)

param(
    [int]$Players = 8,
    [switch]$Uninstall,
    [switch]$Status,
    [string]$GameDir = '',
    [switch]$Pause
)

$ErrorActionPreference = 'Stop'
$ExeName   = 'Medieval_Dynasty-Win64-Shipping.exe'
$ExeSubDir = 'Medieval_Dynasty\Binaries\Win64'
$IniPath   = Join-Path $env:LOCALAPPDATA 'Medieval_Dynasty\Saved\Config\WindowsNoEditor\Game.ini'
$Section   = '[/Script/Engine.GameSession]'

# Code that stores the lobby size: mov ecx,[rsp+0A8h] -> patched to mov ecx,<n> ; nop ; nop
# Surrounding bytes are included so the match is unique and survives only on compatible game versions.
$Prefix    = [byte[]](0x88,0x88,0x9A,0x00,0x00,0x00)
$Original  = [byte[]](0x8B,0x8C,0x24,0xA8,0x00,0x00,0x00)
$Suffix    = [byte[]](0x89,0x88,0x9C,0x00,0x00,0x00)

function Done($code) {
    if ($Pause) { Write-Host ''; Read-Host 'Press Enter to close' | Out-Null }
    exit $code
}
function Fail($msg) { Write-Host ''; Write-Host "ERROR: $msg" -ForegroundColor Red; Done 1 }

function To-Latin1([byte[]]$b) { [System.Text.Encoding]::GetEncoding(28591).GetString($b) }
function Esc([byte[]]$b) { ($b | ForEach-Object { '\x{0:X2}' -f $_ }) -join '' }

# ---------- locate the game ----------
function Test-Win64Dir($d) { $d -and (Test-Path (Join-Path $d $ExeName)) }

function Find-GameWin64 {
    $cands = @()
    if ($GameDir) { $cands += $GameDir; $cands += (Join-Path $GameDir $ExeSubDir) }
    $here = $PSScriptRoot
    $cands += $here
    $cands += (Join-Path $here $ExeSubDir)
    $p = $here
    for ($i = 0; $i -lt 4 -and $p; $i++) { $p = Split-Path $p -Parent; if ($p) { $cands += $p; $cands += (Join-Path $p $ExeSubDir) } }
    # Steam libraries
    $steam = $null
    try { $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath } catch {}
    if (-not $steam) { try { $steam = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction Stop).InstallPath } catch {} }
    if ($steam) {
        $libs = @($steam)
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += ($m.Groups[1].Value -replace '\\\\', '\') }
        }
        foreach ($l in $libs) { $cands += (Join-Path $l "steamapps\common\Medieval Dynasty\$ExeSubDir") }
    }
    foreach ($c in $cands) { if (Test-Win64Dir $c) { return (Resolve-Path $c).Path } }
    return $null
}

$win64 = Find-GameWin64
if (-not $win64) {
    Write-Host 'Could not find Medieval Dynasty automatically.'
    $entered = Read-Host 'Paste your game folder (Steam: right-click game > Manage > Browse local files)'
    $entered = $entered.Trim('"', ' ')
    if (Test-Win64Dir $entered) { $win64 = $entered }
    elseif (Test-Win64Dir (Join-Path $entered $ExeSubDir)) { $win64 = Join-Path $entered $ExeSubDir }
    else { Fail "No $ExeName found there." }
}
$exe = Join-Path $win64 $ExeName
Write-Host "Game: $exe"

# ---------- read current state ----------
$bytes = [System.IO.File]::ReadAllBytes($exe)
$text  = To-Latin1 $bytes
$reOrig    = [regex]((Esc $Prefix) + (Esc $Original) + (Esc $Suffix))
$rePatched = [regex]((Esc $Prefix) + '\xB9([\s\S])\x00\x00\x00\x90\x90' + (Esc $Suffix))
$mO = $reOrig.Matches($text)
$mP = $rePatched.Matches($text)

$state = $null; $offset = -1; $lobby = 4
if ($mO.Count -eq 1 -and $mP.Count -eq 0) { $state = 'original'; $offset = $mO[0].Index + $Prefix.Length }
elseif ($mP.Count -eq 1 -and $mO.Count -eq 0) { $state = 'patched'; $offset = $mP[0].Index + $Prefix.Length; $lobby = [int]$bytes[$offset + 1] }

function Get-IniMaxPlayers {
    if (-not (Test-Path $IniPath)) { return $null }
    $in = $false
    foreach ($line in (Get-Content $IniPath)) {
        $t = $line.Trim()
        if ($t.StartsWith('[')) { $in = ($t -eq $Section); continue }
        if ($in -and $t -match '^MaxPlayers\s*=\s*(\d+)') { return [int]$Matches[1] }
    }
    return $null
}

function Set-IniMaxPlayers([object]$value) {   # $null removes the setting
    $lines = New-Object System.Collections.Generic.List[string]
    if (Test-Path $IniPath) { foreach ($l in (Get-Content $IniPath)) { $lines.Add($l) } }
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq $Section) { $start = $i; break } }
    if ($start -lt 0) {
        if ($null -eq $value) { return }
        while ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -eq '') { $lines.RemoveAt($lines.Count - 1) }
        if ($lines.Count -gt 0) { $lines.Add('') }
        $lines.Add($Section); $lines.Add("MaxPlayers=$value")
    } else {
        $end = $lines.Count
        for ($i = $start + 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim().StartsWith('[')) { $end = $i; break } }
        $found = $false
        for ($i = $end - 1; $i -gt $start; $i--) {
            if ($lines[$i].Trim() -match '^MaxPlayers\s*=') {
                if ($null -eq $value -or $found) { $lines.RemoveAt($i) } else { $lines[$i] = "MaxPlayers=$value"; $found = $true }
            }
        }
        if (-not $found -and $null -ne $value) { $lines.Insert($start + 1, "MaxPlayers=$value") }
        # drop the section header if it is now empty
        $hasKeys = $false
        $end = $lines.Count
        for ($i = $start + 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim().StartsWith('[')) { $end = $i; break } }
        for ($i = $start + 1; $i -lt $end; $i++) { if ($lines[$i].Trim() -ne '') { $hasKeys = $true } }
        if (-not $hasKeys) { for ($i = $end - 1; $i -ge $start; $i--) { $lines.RemoveAt($i) } }
    }
    $dir = Split-Path $IniPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($IniPath, (($lines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
}

function Show-Status {
    $ini = Get-IniMaxPlayers
    switch ($state) {
        'original' { Write-Host 'Lobby size (game exe): 4  (original, not patched)' }
        'patched'  { Write-Host "Lobby size (game exe): $lobby  (patched)" }
        default    { Write-Host 'Lobby size (game exe): UNKNOWN - this game version is not recognised' -ForegroundColor Yellow }
    }
    if ($null -eq $ini) { Write-Host 'Host join limit (Game.ini): not set (game default)' }
    else { Write-Host "Host join limit (Game.ini): $ini" }
}

if ($Status) { Show-Status; Done 0 }

if (-not $state) {
    Fail ("This version of Medieval_Dynasty-Win64-Shipping.exe is not recognised (matches: original=$($mO.Count), patched=$($mP.Count)).`n" +
          "The game was probably updated and the code moved. Nothing was changed. Check for a newer version of this mod.")
}

if (Get-Process -Name 'Medieval_Dynasty-Win64-Shipping' -ErrorAction SilentlyContinue) { Fail 'Close the game first.' }

if ($Uninstall) {
    for ($i = 0; $i -lt $Original.Length; $i++) { $bytes[$offset + $i] = $Original[$i] }
    if ($state -eq 'patched') { [System.IO.File]::WriteAllBytes($exe, $bytes) }
    Set-IniMaxPlayers $null
    Write-Host ''
    Write-Host 'Uninstalled: back to the original 4-player game.' -ForegroundColor Green
    Done 0
}

if ($Players -lt 2 -or $Players -gt 64) { Fail 'Player count must be between 2 and 64.' }

if ($state -eq 'original') {
    $bak = "$exe.orig"
    if (-not (Test-Path $bak)) { Copy-Item $exe $bak; Write-Host "Backup of the original exe: $bak" }
}
$new = [byte[]](0xB9, [byte]$Players, 0x00, 0x00, 0x00, 0x90, 0x90)
for ($i = 0; $i -lt $new.Length; $i++) { $bytes[$offset + $i] = $new[$i] }
[System.IO.File]::WriteAllBytes($exe, $bytes)
Set-IniMaxPlayers $Players

Write-Host ''
Write-Host "Done: co-op player cap is now $Players (you need to be the host)." -ForegroundColor Green
Done 0
