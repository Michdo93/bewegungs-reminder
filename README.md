# 🪑 40-15-5 Bewegungs-Reminder

> **40 Minuten sitzen – 15 Minuten stehen – 5 Minuten bewegen.**  
> Ein schlanker Windows-Tray-Timer, der Informatiker und andere Schreibtischtäter daran erinnert, ihren Körper nicht zu vergessen.

---

## Inhaltsverzeichnis

1. [Warum dieses Tool?](#warum-dieses-tool)
2. [Die 40-15-5-Regel erklärt](#die-40-15-5-regel-erklärt)
3. [Funktionsübersicht](#funktionsübersicht)
4. [Voraussetzungen](#voraussetzungen)
5. [Installation (automatisch)](#installation-automatisch)
6. [Installation (manuell)](#installation-manuell)
7. [Bedienung](#bedienung)
8. [Autostart](#autostart)
9. [Projektstruktur](#projektstruktur)
10. [Häufige Probleme](#häufige-probleme)
11. [Lizenz](#lizenz)

---

## Warum dieses Tool?

Wer täglich 8 Stunden oder mehr vor dem Rechner sitzt, riskiert langfristig Rückenschmerzen, Verspannungen, Durchblutungsstörungen und eine ganze Reihe weiterer Beschwerden, die unter dem Begriff „sitzende Lebensweise" zusammengefasst werden. Studien zeigen, dass selbst regelmäßiger Sport nach Feierabend das stundenlange ununterbrochene Sitzen nicht vollständig kompensiert.

Das Problem: Im Flow vergisst man schlicht, aufzustehen. Meetings, Deadlines, ein kniffliger Bug – und plötzlich sind vier Stunden vergangen, ohne dass man sich auch nur einmal gestreckt hat.

Dieser Reminder löst das Problem mit minimalem Aufwand: Er läuft unauffällig im System-Tray, gibt zum richtigen Zeitpunkt eine Benachrichtigung aus und erinnert mit einem akustischen Signal – ohne den Arbeitsfluss mehr als nötig zu unterbrechen.

---

## Die 40-15-5-Regel erklärt

Das Programm folgt einem dreiteiligen Zyklus, der sich kontinuierlich wiederholt:

| Phase | Dauer | Farbe im Icon | Was tun? |
|---|---|---|---|
| 🪑 **Sitzen** | 40 Minuten | Grün | Normal arbeiten |
| 🧍 **Stehen** | 15 Minuten | Gelb/Orange | Aufstehen, Bildschirm auf Augenhöhe bringen, im Stehen weiterarbeiten |
| 🚶 **Bewegen** | 5 Minuten | Rot | Kurz spazieren gehen, strecken, Treppen steigen, Wasser holen |

Nach den 5 Minuten Bewegung beginnt der Zyklus von vorne mit 40 Minuten Sitzen.

### Warum genau diese Aufteilung?

- **40 Minuten Sitzen** ist lang genug, um produktiv in einer Aufgabe zu versinken, aber kurz genug, um keine dauerhaften Beschwerden zu verursachen.
- **15 Minuten Stehen** reicht aus, um den Kreislauf anzuregen und die Wirbelsäule zu entlasten. Viele Aufgaben (Lesen, Calls, Reviewen) lassen sich problemlos im Stehen erledigen.
- **5 Minuten Bewegen** aktiviert die Muskulatur und sorgt dafür, dass auch die Gelenke der Beine und Hüfte regelmäßig durchbewegt werden.

---

## Funktionsübersicht

- **System-Tray-Icon** mit farbigem Fortschrittsring – man sieht auf einen Blick, wie weit die aktuelle Phase fortgeschritten ist
- **Windows-Benachrichtigung** (Toast-Popup unten rechts) bei jedem Phasenwechsel
- **Akustisches Signal** – je nach Phase ein anderer Ton (aufsteigend beim Stehen, lebhaft beim Bewegen, sanft beim Sitzen)
- **Vollständige manuelle Steuerung** per Rechtsklick-Menü:
  - Starten, Pausieren, Fortsetzen
  - Aktuelle Phase neu starten
  - Phase überspringen
  - Alles zurücksetzen
- **Lautloser Hintergrundbetrieb** – kein Konsolenfenster, kein Aufploppen beim Windows-Start
- **Autostart** – startet automatisch mit Windows, ohne dass man daran denken muss

---

## Voraussetzungen

- Windows 10 (Version 1809 oder neuer) oder Windows 11
- Internetverbindung für die automatische Installation
- Administratorrechte sind **nicht** erforderlich – alles wird im Benutzerverzeichnis installiert

Die folgenden Programme werden vom Setup-Script bei Bedarf automatisch installiert:

- **Python 3** (via winget)
- **git** (via winget)
- **pystray** und **Pillow** (via pip, im venv)

---

## Installation (automatisch)

Die einfachste Methode. Ein einziger Befehl in der PowerShell genügt:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://bit.ly/XXXXXXX | iex
```

> **Hinweis:** Die ExecutionPolicy wird nur für diese eine PowerShell-Session auf `Bypass` gesetzt – keine dauerhafte Systemänderung.

Das Script erledigt dann automatisch folgende Schritte:

1. Prüft, ob Python 3 installiert ist – falls nicht, wird es via `winget` nachinstalliert
2. Prüft, ob git installiert ist – falls nicht, wird es via `winget` nachinstalliert
3. Klont dieses Repository nach `%LOCALAPPDATA%\bewegungs-reminder`
4. Erstellt ein Python Virtual Environment direkt im Projektordner
5. Installiert alle Abhängigkeiten (`pystray`, `Pillow`) im venv
6. Legt eine Autostart-Verknüpfung im Windows-Autostart-Ordner an
7. Startet den Reminder sofort – das Tray-Icon erscheint ohne Neustart

### Was passiert, wenn ich das Script erneut ausführe?

Das Script ist idempotent: Es erkennt, ob das Repository bereits vorhanden ist, und führt in dem Fall stattdessen `git pull` aus, um auf den neuesten Stand zu kommen. Das venv und der Autostart-Eintrag werden ebenfalls aktualisiert.

---

## Installation (manuell)

Falls du die automatische Installation lieber nicht verwenden möchtest oder etwas anpassen willst:

### Schritt 1: Repository klonen

```powershell
git clone https://github.com/DEIN-USER/bewegungs-reminder.git
cd bewegungs-reminder
```

### Schritt 2: Virtual Environment erstellen

```powershell
python -m venv .
```

### Schritt 3: Abhängigkeiten installieren

```powershell
.\Scripts\pip install -r requirements.txt
```

### Schritt 4: Programm starten (zum Testen)

```powershell
.\Scripts\pythonw.exe bewegungs_reminder.py
```

`pythonw.exe` startet das Script ohne Konsolenfenster. Zum Debuggen kann stattdessen `python.exe` verwendet werden, dann ist die Konsole sichtbar.

### Schritt 5: Autostart manuell einrichten

Den Autostart-Ordner öffnen:

```powershell
explorer shell:startup
```

Dort eine neue Textdatei `BewegungsReminder.vbs` mit folgendem Inhalt anlegen (Pfade entsprechend anpassen):

```vbscript
Set oShell = CreateObject("WScript.Shell")
oShell.Run """C:\Users\DEIN-NAME\AppData\Local\bewegungs-reminder\Scripts\pythonw.exe"" ""C:\Users\DEIN-NAME\AppData\Local\bewegungs-reminder\bewegungs_reminder.py""", 0, False
```

---

## Bedienung

Das Programm läuft vollständig im System-Tray (Bereich unten rechts neben der Uhr). Falls das Icon nicht sichtbar ist, auf den kleinen Pfeil `^` in der Taskleiste klicken – dort sind versteckte Tray-Icons.

**Rechtsklick auf das Icon** öffnet das Steuermenü:

| Menüpunkt | Funktion |
|---|---|
| `[Laeuft] Jetzt: SITZEN (38:21)` | Statusanzeige – zeigt Phase und verbleibende Zeit (nicht klickbar) |
| **Start / Weiter** | Timer starten oder nach einer Pause fortsetzen |
| **Pause** | Timer anhalten, z.B. für Mittagspause oder Meeting |
| **Phase neu starten** | Aktuelle Phase von 0 beginnen, z.B. wenn man zu früh aufgestanden ist |
| **Phase überspringen** | Sofort zur nächsten Phase wechseln |
| **Alles zurücksetzen** | Timer komplett stoppen und auf Phase 1 (Sitzen) zurücksetzen |
| **Beenden** | Programm beenden |

### Typische Szenarien

**Arbeitsbeginn:** Reminder starten → `Start / Weiter` klicken → arbeiten.

**Mittagspause:** `Pause` klicken, Mittagessen genießen, danach `Start / Weiter` – der Timer macht genau da weiter, wo er aufgehört hat.

**Unerwartetes Meeting:** `Pause` klicken. Nach dem Meeting entweder fortsetzen oder mit `Phase neu starten` frisch beginnen.

**Man hat die Steh-Phase verpasst:** `Phase überspringen` direkt zur Beweg-Phase, oder einfach weiterlaufen lassen.

**Feierabend:** Einfach den PC herunterfahren – beim nächsten Start beginnt der Timer automatisch wieder (muss dann manuell gestartet werden, startet nicht von selbst im laufenden Zustand).

### Das Tray-Icon verstehen

Das Icon zeigt einen farbigen Fortschrittsring:

- **Grüner Ring** → Sitz-Phase läuft
- **Gelb/oranger Ring** → Steh-Phase läuft
- **Roter Ring** → Beweg-Phase läuft
- **Grauer Balken-Pause-Symbol** → Timer ist pausiert

Beim Hover über das Icon (Maus draufhalten) erscheint ein Tooltip mit Phase, verbleibender Zeit und Status.

---

## Autostart

Der Autostart wird durch eine `.vbs`-Datei im Windows-Autostart-Ordner realisiert. Diese Methode hat gegenüber einem direkten Shortcut auf das Python-Script zwei Vorteile:

1. **Kein Konsolenfenster** – `wscript.exe` führt die VBS-Datei still aus, die wiederum `pythonw.exe` startet
2. **Zuverlässigkeit** – direkte Shortcuts auf `.py`-Dateien mit Argumenten werden von manchen Windows-Versionen nicht korrekt aufgelöst

Den Autostart-Ordner kann man jederzeit manuell öffnen:

```powershell
explorer shell:startup
```

Um den Autostart-Eintrag zu entfernen, einfach die Datei `BewegungsReminder.lnk` aus diesem Ordner löschen.

---

## Projektstruktur

```
bewegungs-reminder/
│
├── bewegungs_reminder.py   # Hauptprogramm (Timer, Tray-Icon, Benachrichtigungen)
├── requirements.txt        # Python-Abhängigkeiten (pystray, Pillow)
├── setup.ps1               # Automatisches Setup-Script für Windows
├── README.md               # Diese Datei
│
├── Scripts/                # Wird von python -m venv . erstellt
│   ├── python.exe          # venv-Python (für pip, Tests)
│   ├── pythonw.exe         # venv-Python ohne Konsolenfenster (für Autostart)
│   └── pip.exe
│
└── start_reminder.vbs      # Wird vom Setup-Script erstellt, startet pythonw lautlos
```

Die Ordner `Scripts/`, `Lib/`, `Include/` und `pyvenv.cfg` werden automatisch vom venv erzeugt und sind nicht Teil des Repositories (via `.gitignore` ausgeschlossen).

---

## Häufige Probleme

### Das Icon erscheint nicht im System-Tray

- In der Taskleiste auf `^` klicken – das Icon könnte im versteckten Bereich sein
- Prüfen ob `pythonw.exe` in der Task-Manager-Prozessliste läuft (`Strg+Umschalt+Esc`)
- Zum Testen statt `pythonw.exe` kurz `python.exe` verwenden – dann sieht man eventuelle Fehlermeldungen in der Konsole

### `irm ... | iex` wird blockiert

Windows blockiert PowerShell-Scripts standardmäßig. Die ExecutionPolicy für die aktuelle Session umgehen:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://bit.ly/XXXXXXX | iex
```

### Python wurde installiert, aber nicht gefunden

Nach der winget-Installation von Python muss ein neues Terminal geöffnet werden, damit der aktualisierte PATH gilt. Das Setup-Script versucht das automatisch zu lösen, aber ein Neustart des Terminals ist der zuverlässigste Weg.

### winget ist nicht verfügbar

winget ist ab Windows 10 Version 1809 verfügbar und wird über den „App Installer" aus dem Microsoft Store bereitgestellt. Falls winget fehlt:

1. Microsoft Store öffnen
2. Nach „App Installer" suchen
3. Installieren/Aktualisieren
4. Danach Setup-Script erneut ausführen

Alternativ Python manuell von [python.org](https://www.python.org/downloads/) installieren.

### Benachrichtigungen erscheinen nicht

- In den Windows-Einstellungen prüfen: `System → Benachrichtigungen` → sicherstellen, dass Benachrichtigungen aktiviert sind
- Im Fokus-Assistenten (`Nicht stören`) können Benachrichtigungen unterdrückt werden

### Kein Ton

- Systemlautstärke prüfen
- `winsound` ist Teil der Python-Standardbibliothek und sollte immer verfügbar sein – falls doch ein Fehler auftritt, läuft der Timer still weiter

### Das Programm nach einem Update aktualisieren

Setup-Script einfach erneut ausführen. Es erkennt das vorhandene Repository und führt `git pull` aus, danach werden Abhängigkeiten aktualisiert und der Autostart-Eintrag neu gesetzt.

---

## Lizenz

MIT License – mach damit was du willst.