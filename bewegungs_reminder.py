"""
40-15-5 Bewegungs-Reminder
==========================
40 Min sitzen → 15 Min stehen → 5 Min bewegen → repeat

Steuerung per System-Tray-Icon (rechts unten in der Taskleiste).
Benötigt: pip install pystray pillow
"""

import threading
import time
import sys
import math
import winsound
import ctypes
from enum import Enum
from PIL import Image, ImageDraw, ImageFont
import pystray
from pystray import MenuItem as item

# ── Phasen-Definition ─────────────────────────────────────────────────────────
class Phase(Enum):
    SITZEN   = ("sitzen",   40 * 60, "🪑",  "Jetzt: SITZEN",   "Du darfst dich wieder hinsetzen.",         (0x1a, 0x6b, 0x3c))
    STEHEN   = ("stehen",   15 * 60, "🧍",  "Jetzt: STEHEN",   "Zeit aufzustehen! Bildschirm auf Augenhöhe.", (0xd4, 0x8a, 0x0a))
    BEWEGEN  = ("bewegen",   5 * 60, "🚶",  "Jetzt: BEWEGEN",  "Geh kurz spazieren oder strecke dich!",    (0xc0, 0x39, 0x2b))

    def __init__(self, key, duration, emoji, title, message, color):
        self.key      = key
        self.duration = duration
        self.emoji    = emoji
        self.title    = title
        self.message  = message
        self.color    = color   # RGB

PHASE_ORDER = [Phase.SITZEN, Phase.STEHEN, Phase.BEWEGEN]

# ── Toast-Benachrichtigung (Windows native) ────────────────────────────────────
def show_toast(title: str, message: str):
    """Zeigt eine Windows-Balloon-Notification via Shell."""
    try:
        # Neuere Windows 10/11 Toast über PowerShell
        ps_script = f"""
Add-Type -AssemblyName System.Windows.Forms
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.BalloonTipTitle = '{title}'
$notify.BalloonTipText  = '{message}'
$notify.Visible = $True
$notify.ShowBalloonTip(6000)
Start-Sleep -Milliseconds 6500
$notify.Dispose()
"""
        import subprocess
        subprocess.Popen(
            ["powershell", "-WindowStyle", "Hidden", "-Command", ps_script],
            creationflags=0x08000000  # CREATE_NO_WINDOW
        )
    except Exception as e:
        print(f"Toast-Fehler: {e}")

# ── Akustisches Signal ─────────────────────────────────────────────────────────
def play_sound(phase: Phase):
    """Spielt einen kurzen, unterschiedlichen Ton je nach Phase."""
    try:
        if phase == Phase.STEHEN:
            # Aufsteigend: steh auf!
            for freq in [600, 800, 1000]:
                winsound.Beep(freq, 180)
        elif phase == Phase.BEWEGEN:
            # Lebhaft: beweg dich!
            for freq in [800, 1000, 800, 1200]:
                winsound.Beep(freq, 140)
        else:  # SITZEN
            # Sanft absteigend: komm zur Ruhe
            for freq in [1000, 800, 600]:
                winsound.Beep(freq, 200)
    except Exception:
        pass  # winsound nicht verfügbar → still weitermachen

# ── Tray-Icon generieren ───────────────────────────────────────────────────────
def make_tray_icon(phase: Phase, paused: bool, progress: float) -> Image.Image:
    """Erstellt ein 64×64-Icon mit Fortschrittsring."""
    size = 64
    img  = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d    = ImageDraw.Draw(img)

    r, g, b = phase.color
    fg  = (r, g, b, 255)
    bg  = (r, g, b, 60)
    cx, cy, radius = size // 2, size // 2, 28

    # Hintergrundkreis
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=bg)

    # Fortschrittsring (Bogensegment)
    if not paused and progress > 0:
        angle = int(progress * 360)
        d.arc([cx - radius, cy - radius, cx + radius, cy + radius],
              start=-90, end=-90 + angle, fill=fg, width=5)

    # Pause-Symbol
    if paused:
        d.rectangle([cx - 10, cy - 12, cx - 4, cy + 12], fill=(200, 200, 200, 220))
        d.rectangle([cx + 4,  cy - 12, cx + 10, cy + 12], fill=(200, 200, 200, 220))
    else:
        # Kleines Emoji-ähnliches Symbol: einfacher Kreis in Mitte
        d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=fg)

    return img

# ── Haupt-Timer-Logik ──────────────────────────────────────────────────────────
class MovementTimer:
    def __init__(self):
        self.phase_index  = 0
        self.elapsed      = 0.0
        self.running      = False
        self.paused       = False
        self._lock        = threading.Lock()
        self._stop_event  = threading.Event()
        self.icon         = None   # wird von pystray gesetzt

    @property
    def current_phase(self) -> Phase:
        return PHASE_ORDER[self.phase_index]

    @property
    def progress(self) -> float:
        """0.0 … 1.0 Fortschritt in aktueller Phase."""
        dur = self.current_phase.duration
        return min(self.elapsed / dur, 1.0) if dur > 0 else 0.0

    @property
    def remaining_str(self) -> str:
        rem = max(0, self.current_phase.duration - int(self.elapsed))
        m, s = divmod(rem, 60)
        return f"{m:02d}:{s:02d}"

    # ── Steuerung ──────────────────────────────────────────────────────────────
    def start_or_resume(self):
        with self._lock:
            if not self.running:
                self.running = True
                self.paused  = False
                t = threading.Thread(target=self._tick, daemon=True)
                t.start()
            else:
                self.paused = False
        self._refresh_icon()

    def pause(self):
        with self._lock:
            self.paused = True
        self._refresh_icon()

    def reset(self):
        with self._lock:
            self.paused      = False
            self.elapsed     = 0.0
            # running bleibt wie es ist
        self._refresh_icon()

    def full_reset(self):
        """Alles zurück auf Phase 1 (Sitzen), Timer gestoppt."""
        with self._lock:
            self.phase_index = 0
            self.elapsed     = 0.0
            self.running     = False
            self.paused      = False
        self._refresh_icon()

    def skip_phase(self):
        """Nächste Phase sofort auslösen."""
        with self._lock:
            self.elapsed = self.current_phase.duration
        # Tick wird das sauber abhandeln

    # ── Tick-Thread ───────────────────────────────────────────────────────────
    def _tick(self):
        interval = 1.0  # Sekunden-Takt
        while True:
            time.sleep(interval)
            with self._lock:
                if not self.running:
                    return
                if self.paused:
                    continue
                self.elapsed += interval
                phase    = self.current_phase
                done     = self.elapsed >= phase.duration

            if done:
                self._advance_phase()
            else:
                self._refresh_icon()

    def _advance_phase(self):
        with self._lock:
            self.phase_index = (self.phase_index + 1) % len(PHASE_ORDER)
            self.elapsed     = 0.0
            phase = self.current_phase

        # Benachrichtigung & Ton in eigenem Thread, damit Tick nicht blockiert
        threading.Thread(target=self._notify, args=(phase,), daemon=True).start()
        self._refresh_icon()

    def _notify(self, phase: Phase):
        play_sound(phase)
        show_toast(phase.title, phase.message)

    # ── Icon aktualisieren ────────────────────────────────────────────────────
    def _refresh_icon(self):
        if self.icon is None:
            return
        phase = self.current_phase
        prog  = self.progress
        new_img = make_tray_icon(phase, self.paused, prog)

        # Tooltip
        state = "⏸ Pausiert" if self.paused else ("▶ Läuft" if self.running else "⏹ Gestoppt")
        tooltip = f"40-15-5 | {phase.title} | {self.remaining_str} | {state}"

        self.icon.icon  = new_img
        self.icon.title = tooltip
        self.icon.update_menu()


# ── pystray-Menü aufbauen ──────────────────────────────────────────────────────
def build_menu(timer: MovementTimer):
    # pystray erwartet für dynamische Labels eine einstellige Callable (nur item)
    def phase_label(menu_item):
        p = timer.current_phase
        s = "[Pause]" if timer.paused else ("[Laeuft]" if timer.running else "[Stop]")
        return f"{s}  {p.title}  ({timer.remaining_str})"

    return pystray.Menu(
        item(phase_label, None, enabled=False),
        pystray.Menu.SEPARATOR,
        item("Start / Weiter",      lambda icon, i: timer.start_or_resume()),
        item("Pause",               lambda icon, i: timer.pause()),
        item("Phase neu starten",   lambda icon, i: timer.reset()),
        item("Phase ueberspringen", lambda icon, i: timer.skip_phase()),
        pystray.Menu.SEPARATOR,
        item("Alles zuruecksetzen", lambda icon, i: timer.full_reset()),
        pystray.Menu.SEPARATOR,
        item("Beenden",             lambda icon, i: icon.stop()),
    )


# ── Einstiegspunkt ─────────────────────────────────────────────────────────────
def main():
    timer = MovementTimer()

    # Initiales Icon
    init_img = make_tray_icon(Phase.SITZEN, paused=False, progress=0.0)

    icon = pystray.Icon(
        name    = "40-15-5",
        icon    = init_img,
        title   = "40-15-5 Bewegungs-Reminder",
        menu    = build_menu(timer),
    )
    timer.icon = icon

    # Icon-Refresh-Thread (alle 5 Sek. auch wenn kein Phasenwechsel)
    def periodic_refresh():
        while True:
            time.sleep(5)
            timer._refresh_icon()
    threading.Thread(target=periodic_refresh, daemon=True).start()

    print("40-15-5 Reminder läuft im System-Tray.")
    print("Rechtsklick auf das Icon in der Taskleiste zum Steuern.")
    icon.run()


if __name__ == "__main__":
    main()