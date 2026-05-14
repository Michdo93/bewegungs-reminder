#Requires -Version 5.1
<#
.SYNOPSIS
    Setup-Script fuer den 40-15-5 Bewegungs-Reminder
.DESCRIPTION
    - Prueft / installiert Python 3 via winget
    - Erstellt ein venv im Repo-Verzeichnis
    - Installiert Abhaengigkeiten (requirements.txt)
    - Legt einen Autostart-Eintrag an (startet lautlos via pythonw.exe)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Konfiguration ──────────────────────────────────────────────────────────────
$RepoUrl    = "https://github.com/Michdo93/bewegungs-reminder"   # <-- anpassen
$RepoName   = "bewegungs-reminder"                             # <-- Ordnername nach dem Clone
$InstallDir = Join-Path $env:LOCALAPPDATA $RepoName           # z.B. C:\Users\...\AppData\Local\bewegungs-reminder
$MainScript = "bewegungs_reminder.py"
$AppName    = "BewegungsReminder"
# ──────────────────────────────────────────────────────────────────────────────

function Write-Step($msg) {
    Write-Host ""
    Write-Host ">>> $msg" -ForegroundColor Cyan
}

function Write-OK($msg) {
    Write-Host "    OK: $msg" -ForegroundColor Green
}

function Write-Fail($msg) {
    Write-Host "    FEHLER: $msg" -ForegroundColor Red
    exit 1
}

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

    # Winget-Verfuegbarkeit pruefen
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Fail ("winget nicht gefunden. Bitte Windows 10 1809+ oder " +
                    "App Installer aus dem Microsoft Store installieren: " +
                    "https://aka.ms/getwinget")
    }

    winget install --id Python.Python.3 --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Write-Fail "winget-Installation fehlgeschlagen." }

    # PATH neu einlesen (winget aendert ihn fuer die aktuelle Session nicht automatisch)
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
    git pull
    Pop-Location
} else {
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
    git clone $RepoUrl $InstallDir
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

$scriptPath  = Join-Path $InstallDir $MainScript
if (-not (Test-Path $scriptPath)) {
    Write-Fail "$MainScript nicht im Repo gefunden."
}

# pythonw.exe: fuehrt .py aus OHNE Konsolenfenster
# Wir legen eine .vbs-Datei an, die pythonw lautlos startet -
# direkter Autostart-Shortcut auf pythonw + Argument funktioniert
# in manchen Windows-Versionen nicht zuverlaessig.

$vbsPath = Join-Path $InstallDir "start_reminder.vbs"
$vbsContent = @"
' Startet den Bewegungs-Reminder lautlos (kein Konsolenfenster)
Set oShell = CreateObject("WScript.Shell")
oShell.Run """$venvPythonW"" ""$scriptPath""", 0, False
"@
Set-Content -Path $vbsPath -Value $vbsContent -Encoding UTF8

# Autostart-Ordner des aktuellen Benutzers
$startupFolder = [System.Environment]::GetFolderPath("Startup")
$shortcutPath  = Join-Path $startupFolder "$AppName.lnk"

$wsh      = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath       = "wscript.exe"
$shortcut.Arguments        = "`"$vbsPath`""
$shortcut.WorkingDirectory = $InstallDir
$shortcut.Description      = "40-15-5 Bewegungs-Reminder"
$shortcut.Save()

Write-OK "Autostart-Verknuepfung erstellt: $shortcutPath"

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