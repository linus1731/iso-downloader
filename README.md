# ISO Repository 🐧

Ein automatisiertes System zum Herunterladen und Verwalten von Linux-ISO-Dateien.

## 📋 Übersicht

Dieses Repository enthält Scripts zum automatischen Herunterladen verschiedener Linux-Distributionen und deren Verwaltung. Perfekt für System-Administratoren, Entwickler oder Linux-Enthusiasten, die mehrere Distributionen bereithalten möchten.

## 🚀 Features

- **Automatischer Download** von 10 populären Linux-Distributionen
- **Intelligente Duplikat-Erkennung** - überspringt bereits vorhandene ISOs
- **Umfassendes Logging** mit Zeitstempel und Statusmeldungen
- **Retry-Mechanismus** bei fehlgeschlagenen Downloads
- **Progress-Bar** für jeden Download
- **Farbcodierte Ausgabe** für bessere Übersicht
- **Cross-Platform** kompatibel (macOS, Linux)
 - **Subkommandos**: download, status, list, verify
 - **Externe Manifeste**: `isos.list` und `isos.d/*.list` werden automatisch geladen

## 📦 Unterstützte Distributionen

| Distribution | Version | Größe | Architektur |
|--------------|---------|--------|-------------|
| 🎯 **Arch Linux** | 2025.10.01 | ~1.4GB | x86_64 |
| 🐉 **Kali Linux** | 2025.3 | ~4.3GB | amd64 |
| 🟠 **Ubuntu Server** | 24.04.3 LTS | ~3.1GB | amd64 |
| 🌀 **Debian Live** | 13.1.0 | ~1.8GB | amd64 |
| 🔒 **Tails** | 7.0 | ~1.9GB | amd64 |
| 🏔️ **Rocky Linux** | 10.0 | ~9.5GB | aarch64 |
| 🌿 **Linux Mint** | 22.2 Cinnamon | ~2.9GB | 64bit |
| 🦜 **Parrot Security** | 6.4 | ~4.8GB | amd64 |
| ⚡ **Elementary OS** | 8.0 | ~2.5GB | amd64 |
| 🚀 **EndeavourOS** | Mercury Neo | ~2.9GB | x86_64 |

## 🛠️ Installation & Setup

### Voraussetzungen

```bash
# macOS (mit Homebrew)
brew install curl

# Ubuntu/Debian
sudo apt update && sudo apt install curl

# Arch Linux
sudo pacman -S curl

# CentOS/RHEL/Rocky
sudo yum install curl
```

### Repository klonen

```bash
git clone <repository-url>
cd "ISO Repo"
```

### Script ausführbar machen

```bash
chmod +x main.sh
```

## 🎯 Verwendung

Das Script unterstützt Subkommandos. Ohne Argumente lädt es alle ISOs herunter.

### Alle ISOs herunterladen

```bash
./main.sh
```

### Einzelne ISO laden (nach Index oder Name)

```bash
./main.sh download 3
./main.sh download "Ubuntu Server"
```

### Status überprüfen

```bash
./main.sh status            # Lokalstatus
./main.sh status --remote   # Vergleiche mit Remote-Größe (HEAD)
./main.sh status Ubuntu     # Filter nach Name/Teilstring

### ISOs auflisten

./main.sh list

### SHA256-Hash anzeigen (lokal)
### ISO-Links verwalten (Manifeste)

Das Script lädt ISO-Definitionen aus folgenden Dateien automatisch:

- `isos.list` (Hauptdatei im Repo-Verzeichnis)
- allen Dateien `isos.d/*.list`

Format einer Manifest-Zeile: `Name|URL`  (Kommentare mit `#` und leere Zeilen werden ignoriert)

Beispiele:

```bash
# Neuen Eintrag über Subkommando hinzufügen
./main.sh add "Fedora Workstation" "https://download.example.org/fedora-40.iso"

# Manuell per Datei (z. B. für Gruppen):
echo "Fedora KDE|https://mirror.example/fedora-kde.iso" >> isos.d/fedora.list

# Kontrolle
./main.sh list
```

./main.sh verify            # alle vorhandenen
./main.sh verify 2          # nach Index
./main.sh verify Ubuntu     # nach Name
```

## 📊 Script-Ausgabe

### Beispiel einer erfolgreichen Ausführung:

```
════════════════════════════════════════
       ISO Download Script gestartet     
════════════════════════════════════════
[2025-10-05 17:15:04] [INFO] ISO Download Script gestartet
[2025-10-05 17:15:04] [INFO] Log-Datei: iso_download_20251005_171504.log
[2025-10-05 17:15:04] [INFO] Download-Verzeichnis: ./isos
Überprüfe Internetverbindung...
[2025-10-05 17:15:04] [INFO] Internetverbindung verfügbar
Insgesamt 10 ISOs zum Herunterladen

[1/10] Lade herunter: Arch Linux
Starte Download: Arch Linux
████████████████████████████████████████████ 100.0%
✓ Erfolgreich heruntergeladen: Arch Linux

[2/10] Lade herunter: Kali Linux
Datei kali-linux-2025.3-installer-amd64.iso existiert bereits. Überspringe...

════════════════════════════════════════
           Download Zusammenfassung       
════════════════════════════════════════
Erfolgreich: 9 ISOs
Fehlgeschlagen: 1 ISOs
Gesamt: 10 ISOs
```

## 📁 Verzeichnisstruktur

```
ISO Repo/
├── README.md                    # Diese Datei
├── main.sh                    # Hauptscript mit Subkommandos
├── isos.list                  # Haupt-Manifest (Name|URL)
├── isos.d/                    # Zusätzliche Manifest-Dateien (*.list)
├── isos/                       # Download-Verzeichnis
│   ├── archlinux-2025.10.01-x86_64.iso
│   ├── kali-linux-2025.3-installer-amd64.iso
│   ├── ubuntu-24.04.3-live-server-amd64.iso
│   └── ...
└── logs/
    ├── iso_download_20251005_171504.log
    └── ...
```

## ⚙️ Konfiguration

### Script-Einstellungen anpassen

Öffne `main.sh` und modifiziere diese Variablen:

```bash
# Konfiguration
LOG_FILE="iso_download_$(date +%Y%m%d_%H%M%S).log"
DOWNLOAD_DIR="./isos"           # Download-Verzeichnis ändern
MAX_RETRIES=3                   # Anzahl Wiederholungen
TIMEOUT=30                      # Timeout in Sekunden

# Manifeste
# MANIFEST_FILE="./isos.list"
# MANIFEST_DIR="./isos.d"
```

### Neue Distributionen hinzufügen

Füge Einträge in `isos.list` hinzu oder lege Dateien unter `isos.d/*.list` an. Das Script liest beide Quellen automatisch.

```bash
ISOS=(
    "Deine Distribution|https://example.com/distro.iso"
    # ... weitere Einträge
)
```

## 🔧 Troubleshooting

### Häufige Probleme

**Problem:** `Permission denied`
```bash
# Lösung:
chmod +x main.sh
```

**Problem:** `No space left on device`
```bash
# Lösung: Speicherplatz prüfen
df -h
# Oder Download-Verzeichnis ändern
```

**Problem:** Download hängt
```bash
# Lösung: Script unterbrechen (Ctrl+C) und erneut starten
# Das Script überspringt bereits heruntergeladene Dateien
```

**Problem:** Netzwerk-Timeout
```bash
# Lösung: TIMEOUT-Wert in der Konfiguration erhöhen
TIMEOUT=60
```

## 📝 Logs

Jede Script-Ausführung erstellt eine detaillierte Log-Datei:

- **Speicherort:** Gleicher Ordner wie das Script
- **Format:** `iso_download_YYYYMMDD_HHMMSS.log`
- **Inhalt:** Zeitstempel, Status, Fehler, Dateigrößen

### Log-Beispiel:

```
[2025-10-05 17:15:04] [INFO] ISO Download Script gestartet
[2025-10-05 17:15:04] [INFO] Download-Verzeichnis: ./isos
[2025-10-05 17:15:04] [INFO] Internetverbindung verfügbar
[2025-10-05 17:15:04] [INFO] Beginne Download von Arch Linux
[2025-10-05 17:16:30] [SUCCESS] Download erfolgreich: Arch Linux
[2025-10-05 17:16:30] [INFO] Dateigröße: 1.4G
```

## 🔒 Sicherheit

- **Checksums:** Plane Integration von SHA256-Überprüfungen
- **HTTPS:** Alle Downloads erfolgen über verschlüsselte Verbindungen
- **Quellen:** Nur offizielle Mirror-Server werden verwendet

## 🤝 Beitrag leisten

Verbesserungen sind willkommen! So kannst du beitragen:

1. Fork das Repository
2. Erstelle einen Feature-Branch (`git checkout -b feature/amazing-feature`)
3. Committe deine Änderungen (`git commit -m 'Add amazing feature'`)
4. Pushe den Branch (`git push origin feature/amazing-feature`)
5. Öffne einen Pull Request

### Geplante Features

- [ ] Interaktive Distribution-Auswahl
- [ ] SHA256-Checksum-Überprüfung
- [ ] Automatische Updates der Download-URLs
- [ ] GUI-Interface
- [ ] Docker-Container für isolierte Downloads
- [ ] Bandwidth-Limiting
- [ ] Resume unterbrochener Downloads

## 📊 Statistiken

**Gesamte Download-Größe:** ~30GB  
**Durchschnittliche Download-Zeit:** 2-4 Stunden (je nach Internetverbindung)  
**Unterstützte Architekturen:** x86_64, amd64, aarch64  

## 📄 Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Siehe `LICENSE` Datei für Details.

## 📞 Support

Bei Fragen oder Problemen:

- 📧 Öffne ein GitHub Issue
- 📚 Konsultiere die [Wiki-Seiten](wiki-url)
- 💬 Diskutiere in den [GitHub Discussions](discussions-url)

---

**⭐ Gefällt dir dieses Projekt? Gib ihm einen Stern!**

*Letzte Aktualisierung: Oktober 2025*