#!/usr/bin/env bash

# ISO Download Script mit Logging
# Datum: $(date)
# Beschreibung: Script zum Herunterladen verschiedener Linux-ISOs

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Konfiguration
LOG_FILE="iso_download_$(date +%Y%m%d_%H%M%S).log"
DOWNLOAD_DIR="./isos"
MAX_RETRIES=3
TIMEOUT=30

# Erstelle Download-Verzeichnis falls es nicht existiert
mkdir -p "$DOWNLOAD_DIR"

# Logging-Funktion
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Farbige Ausgabe-Funktion
print_colored() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Funktion zum Überprüfen der Internetverbindung
check_internet() {
    print_colored "$BLUE" "Überprüfe Internetverbindung..."
    if ping -c 1 google.com &> /dev/null; then
        log_message "INFO" "Internetverbindung verfügbar"
        return 0
    else
        log_message "ERROR" "Keine Internetverbindung verfügbar"
        print_colored "$RED" "Fehler: Keine Internetverbindung"
        exit 1
    fi
}

# Funktion zum Herunterladen einer Datei
download_iso() {
    local name=$1
    local url=$2
    local filename=$(basename "$url")
    local filepath="$DOWNLOAD_DIR/$filename"
    
    print_colored "$YELLOW" "Starte Download: $name"
    log_message "INFO" "Beginne Download von $name: $url"
    
    # Überprüfe ob Datei bereits existiert
    if [ -f "$filepath" ]; then
        print_colored "$YELLOW" "Datei $filename existiert bereits. Überspringe..."
        log_message "WARNING" "Datei $filename bereits vorhanden, überspringe Download"
        return 0
    fi
    
    local retry_count=0
    while [ $retry_count -lt $MAX_RETRIES ]; do
        # Download mit curl und Progress-Bar
        if curl -L --connect-timeout $TIMEOUT --max-time 0 -# -o "$filepath" "$url"; then
            print_colored "$GREEN" "✓ Erfolgreich heruntergeladen: $name"
            log_message "SUCCESS" "Download erfolgreich: $name -> $filepath"
            
            # Dateigröße loggen
            local filesize=$(ls -lh "$filepath" | awk '{print $5}')
            log_message "INFO" "Dateigröße: $filesize"
            return 0
        else
            retry_count=$((retry_count + 1))
            print_colored "$RED" "✗ Download fehlgeschlagen: $name (Versuch $retry_count/$MAX_RETRIES)"
            log_message "ERROR" "Download fehlgeschlagen für $name, Versuch $retry_count/$MAX_RETRIES"
            
            if [ $retry_count -lt $MAX_RETRIES ]; then
                print_colored "$YELLOW" "Wiederhole in 5 Sekunden..."
                sleep 5
            fi
        fi
    done
    
    print_colored "$RED" "✗ Alle Versuche fehlgeschlagen für: $name"
    log_message "ERROR" "Alle Download-Versuche fehlgeschlagen für $name"
    return 1
}

# Hauptfunktion
main() {
    print_colored "$BLUE" "════════════════════════════════════════"
    print_colored "$BLUE" "       ISO Download Script gestartet     "
    print_colored "$BLUE" "════════════════════════════════════════"
    
    log_message "INFO" "ISO Download Script gestartet"
    log_message "INFO" "Log-Datei: $LOG_FILE"
    log_message "INFO" "Download-Verzeichnis: $DOWNLOAD_DIR"
    
    # Internetverbindung prüfen
    check_internet
    
    # ISO-Definitionen (Name|URL)
    isos=(
        "Arch Linux|https://ftp.halifax.rwth-aachen.de/archlinux/iso/2025.10.01/archlinux-2025.10.01-x86_64.iso"
        "Kali Linux|https://cdimage.kali.org/kali-2025.3/kali-linux-2025.3-installer-amd64.iso"
        "Ubuntu Server|https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso"
        "Debian Live|https://ftp.halifax.rwth-aachen.de/debian-cd/13.1.0-live/amd64/iso-hybrid/debian-live-13.1.0-amd64-standard.iso"
        "Tails|https://download.tails.net/tails/stable/tails-amd64-7.0/tails-amd64-7.0.img"
        "Rocky Linux|https://download.rockylinux.org/pub/rocky/10/isos/aarch64/Rocky-10.0-aarch64-dvd1.iso"
        "Linux Mint|https://mirror.netcologne.de/linuxmint/iso/stable/22.2/linuxmint-22.2-cinnamon-64bit.iso"
        "Parrot Security|https://deb.parrot.sh/parrot/iso/6.4/Parrot-security-6.4_amd64.iso"
        "Elementary OS|https://fra1.dl.elementary.io/download/MTc1OTY3NjM3MQ==/elementaryos-8.0-stable-amd64.20250902rc.iso"
        "EndeavourOS|https://mirror.alpix.eu/endeavouros/iso/EndeavourOS_Mercury-Neo-2025.03.19.iso"
    )
    
    local total_isos=${#isos[@]}
    local current=1
    local successful_downloads=0
    local failed_downloads=0
    
    print_colored "$BLUE" "Insgesamt $total_isos ISOs zum Herunterladen"
    echo
    
    # Durchlaufe alle ISOs
    for iso_entry in "${isos[@]}"; do
        # Teile Name und URL
        local name=$(echo "$iso_entry" | cut -d'|' -f1)
        local url=$(echo "$iso_entry" | cut -d'|' -f2-)
        
        print_colored "$BLUE" "[$current/$total_isos] Lade herunter: $name"
        if download_iso "$name" "$url"; then
            successful_downloads=$((successful_downloads + 1))
        else
            failed_downloads=$((failed_downloads + 1))
        fi
        
        current=$((current + 1))
        echo
    done
    
    # Zusammenfassung
    print_colored "$BLUE" "════════════════════════════════════════"
    print_colored "$BLUE" "           Download Zusammenfassung       "
    print_colored "$BLUE" "════════════════════════════════════════"
    print_colored "$GREEN" "Erfolgreich: $successful_downloads ISOs"
    print_colored "$RED" "Fehlgeschlagen: $failed_downloads ISOs"
    print_colored "$BLUE" "Gesamt: $total_isos ISOs"
    print_colored "$BLUE" "Log-Datei: $LOG_FILE"
    print_colored "$BLUE" "Download-Verzeichnis: $DOWNLOAD_DIR"
    
    log_message "INFO" "Download-Session beendet"
    log_message "INFO" "Erfolgreich: $successful_downloads, Fehlgeschlagen: $failed_downloads, Gesamt: $total_isos"
    
    # Übersicht der heruntergeladenen Dateien
    if [ $successful_downloads -gt 0 ]; then
        print_colored "$BLUE" "Heruntergeladene Dateien:"
        ls -lh "$DOWNLOAD_DIR"/ | grep -v "^total" | while read line; do
            print_colored "$GREEN" "  $line"
        done
    fi
}

# Script starten
main "$@"