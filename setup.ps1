#Requires -Version 5.1
<#
.SYNOPSIS
    Setup-Script fuer den 40-15-5 Bewegungs-Reminder (Fixed Version)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ── Konfiguration ──────────────────────────────────────────────────────────────
$RepoUrl    = "https://github.com/Michdo93/bewegungs-reminder"
$RepoName   = "bewegungs-reminder"
$InstallDir = Join-Path $env:LOCALAPPDATA $RepoName
$MainScript = "bewegungs_reminder.py"
$AppName    = "BewegungsReminder"
# ──────────────────────────────────────────────────────────────────────────────

function Write-Step($msg) { Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "    FEHLER: $msg" -ForegroundColor Red; exit 1 }

# ── 1. Python pruefen / installieren ──────────────────────────────────────────
Write-Step "Pruefe Python 3..."

$pythonCmd = $null
foreach ($cmd in @("python", "python3")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python 3\.") {
            $pythonCmd = $cmd
            Write-OK "$ver gefunden ($cmd)"
            break
        }
    } catch { }
}

if (-not $pythonCmd) {
    Write-Step "Python 3 nicht gefunden - installiere via winget..."

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Fail ("winget nicht gefunden. Bitte Windows 10 1809+ oder " +
                    "App Installer aus dem Microsoft Store installieren: " +
                    "https://aka.ms/getwinget")
    }

    winget install --id Python.Python.3 --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Write-Fail "winget-Installation fehlgeschlagen." }

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") +
                ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    foreach ($cmd in @("python", "python3")) {
        try {
            $ver = & $cmd --version 2>&1
            if ($ver -match "Python 3\.") { $pythonCmd = $cmd; break }
        } catch { }
    }

    if (-not $pythonCmd) {
        Write-Fail ("Python wurde installiert, ist aber noch nicht im PATH. " +
                    "Bitte neues Terminal oeffnen und Script erneut ausfuehren.")
    }
    Write-OK "Python 3 installiert: $(&$pythonCmd --version 2>&1)"
}

# ── 2. git pruefen ─────────────────────────────────────────────────────────────
Write-Step "Pruefe git..."
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Step "git nicht gefunden - installiere via winget..."
    winget install --id Git.Git --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Write-Fail "git-Installation fehlgeschlagen." }

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") +
                ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Fail "git installiert, aber noch nicht im PATH. Neues Terminal oeffnen."
    }
}
Write-OK "git $(git --version)"

# ── 3. Repository klonen / aktualisieren ───────────────────────────────────────
Write-Step "Repository einrichten in: $InstallDir"

if (Test-Path (Join-Path $InstallDir ".git")) {
    Write-Host "    Repo existiert bereits - fuehre git pull aus..." -ForegroundColor Yellow
    Push-Location $InstallDir
    git pull 2>&1 | ForEach-Object { Write-Host "    $_" }
    Pop-Location
} else {
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
    git clone $RepoUrl $InstallDir 2>&1 | ForEach-Object { Write-Host "    $_" }
    if ($LASTEXITCODE -ne 0) { Write-Fail "git clone fehlgeschlagen." }
}
Write-OK "Repository bereit."

# ── 4. venv erstellen ─────────────────────────────────────────────────────────
Write-Step "Erstelle Virtual Environment..."
Push-Location $InstallDir

$venvPython  = Join-Path $InstallDir "Scripts\python.exe"
$venvPythonW = Join-Path $InstallDir "Scripts\pythonw.exe"

if (-not (Test-Path $venvPython)) {
    & $pythonCmd -m venv .
    if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "venv-Erstellung fehlgeschlagen." }
    Write-OK "venv erstellt."
} else {
    Write-OK "venv existiert bereits."
}

# ── 5. Abhaengigkeiten installieren ───────────────────────────────────────────
Write-Step "Installiere Abhaengigkeiten (requirements.txt)..."
$reqFile = Join-Path $InstallDir "requirements.txt"
if (-not (Test-Path $reqFile)) { Pop-Location; Write-Fail "requirements.txt nicht gefunden im Repo." }

& $venvPython -m pip install --upgrade pip --quiet
& $venvPython -m pip install -r $reqFile
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "pip install fehlgeschlagen." }
Write-OK "Abhaengigkeiten installiert."

Pop-Location

# ── 6. Autostart einrichten ───────────────────────────────────────────────────
Write-Step "Richte Autostart ein..."

$scriptPath = Join-Path $InstallDir $MainScript
$venvPythonW = Join-Path $InstallDir "Scripts\pythonw.exe"

$vbsPath = Join-Path $InstallDir "start_reminder.vbs"

# Wir nutzen einfache Anführungszeichen ' für PowerShell, damit der Inhalt 
# EXAKT so übernommen wird. Wir setzen die Pfade manuell ein.
$line1 = 'Set oShell = CreateObject("WScript.Shell")'
$line2 = 'oShell.Run """' + $venvPythonW + '"" ""' + $scriptPath + '""", 0, False'

# Wir fügen die Zeilen zusammen
$vbsContent = $line1 + "`r`n" + $line2

# Out-File mit NoBom sorgt dafür, dass VBScript nicht stirbt
[System.IO.File]::WriteAllText($vbsPath, $vbsContent, [System.Text.Encoding]::ASCII)

# ── 7. Direkt starten ─────────────────────────────────────────────────────────
Write-Step "Starte Reminder jetzt..."
Start-Process "wscript.exe" -ArgumentList "`"$vbsPath`""
Write-OK "Reminder gestartet - Icon erscheint gleich im System-Tray."

# ── Fertig ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup abgeschlossen!" -ForegroundColor Green
Write-Host "  Der Reminder startet ab sofort automatisch" -ForegroundColor Green
Write-Host "  mit Windows. Rechtsklick auf das Tray-Icon" -ForegroundColor Green
Write-Host "  zum Steuern." -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
