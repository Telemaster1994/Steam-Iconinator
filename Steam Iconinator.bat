<# : batch launcher (PowerShell ignores this block)
@echo off
:: Re-launch as admin if needed (Steam's icon folder is under Program Files)
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ([System.IO.File]::ReadAllText('%~f0'))"
exit /b
#>

# ===================== PowerShell part =====================
# Restores missing icons on Steam game shortcuts (.url files).
# Steam shortcuts point to icons in <Steam>\steam\games\<hash>.ico, which
# don't exist on a fresh Windows install. This downloads them from Steam's CDN.

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

# --- Find where Steam is installed ---
$steamPath = $null
try { $steamPath = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath -replace '/', '\' } catch {}
if (-not $steamPath) { try { $steamPath = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction Stop).InstallPath } catch {} }
if (-not $steamPath) { $steamPath = Join-Path ${env:ProgramFiles(x86)} 'Steam' }
$iconDir = Join-Path $steamPath 'steam\games'
New-Item -ItemType Directory -Path $iconDir -Force | Out-Null

Write-Host "Steam folder: $steamPath" -ForegroundColor Cyan
Write-Host "Icon folder:  $iconDir`n" -ForegroundColor Cyan

# --- Places to look for Steam shortcuts ---
$folders = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory'),
    (Join-Path ([Environment]::GetFolderPath('Programs')) 'Steam'),
    (Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'Steam')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

$cdns = @(
    'https://cdn.cloudflare.steamstatic.com',
    'https://cdn.akamai.steamstatic.com',
    'https://steamcdn-a.akamaihd.net'
)

$fixed = 0; $alreadyOk = 0; $failed = @()

foreach ($file in Get-ChildItem -LiteralPath $folders -Filter *.url -File -ErrorAction SilentlyContinue) {
    $text = Get-Content -LiteralPath $file.FullName -Raw

    if ($text -notmatch 'URL=steam://rungameid/(\d+)') { continue }
    $appId = $Matches[1]

    if ($text -notmatch '(?m)^IconFile=(.+?)\s*$') {
        $failed += "$($file.BaseName)  (shortcut has no icon info - recreate it from Steam)"
        continue
    }
    $iconPath = $Matches[1]

    if (Test-Path -LiteralPath $iconPath) { $alreadyOk++; continue }

    $iconName = Split-Path $iconPath -Leaf
    $dest = Join-Path $iconDir $iconName

    Write-Host "Fixing $($file.BaseName) (app $appId)..." -NoNewline

    $got = (Test-Path -LiteralPath $dest)
    if (-not $got) {
        foreach ($cdn in $cdns) {
            try {
                Invoke-WebRequest -Uri "$cdn/steamcommunity/public/images/apps/$appId/$iconName" `
                    -OutFile $dest -UseBasicParsing -ErrorAction Stop
                $got = $true
                break
            } catch { }
        }
    }

    if (-not $got) {
        Write-Host " failed" -ForegroundColor Red
        $failed += "$($file.BaseName)  (icon not found on Steam's servers)"
        continue
    }

    # If the shortcut pointed at an old drive/location, repoint it to the real icon
    if ($iconPath -ne $dest) {
        $newText = [regex]::Replace($text, '(?m)^IconFile=.*$', { param($m) "IconFile=$dest" })
        Set-Content -LiteralPath $file.FullName -Value $newText -NoNewline -Encoding Default
    }

    Write-Host " done" -ForegroundColor Green
    $fixed++
}

# --- Refresh Windows' icon cache ---
try { Start-Process ie4uinit.exe -ArgumentList '-show' -Wait -WindowStyle Hidden } catch {}

Write-Host "`n----------------------------------------"
Write-Host "Fixed:             $fixed" -ForegroundColor Green
Write-Host "Already had icons: $alreadyOk"
if ($failed.Count) {
    Write-Host "Couldn't fix:      $($failed.Count)" -ForegroundColor Yellow
    $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
Write-Host "----------------------------------------"
Write-Host "If any icons still look blank, press F5 on the desktop or sign out and back in."
Read-Host "`nPress Enter to close"
