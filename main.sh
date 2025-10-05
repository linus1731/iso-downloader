#!/usr/bin/env bash

# ISO Download Script mit Logging und Subkommandos
# Datum: $(date)
# Beschreibung: Script zum Herunterladen und Verwalten verschiedener Linux-ISOs

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
HEAD_TIMEOUT=10

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

# Hilfe/Usage
show_usage() {
        cat <<EOF
Verwendung: $0 <kommando> [optionen]

Kommandos:
    download [all|INDEX|NAME]   Lade alle oder eine bestimmte ISO herunter (Standard, wenn kein Kommando angegeben)
    status   [all|INDEX|NAME]   Zeige Status der ISOs (lokal). Mit --remote auch Remote-Größe vergleichen
    list                       Liste aller bekannten ISOs auf
    verify   [all|INDEX|NAME]  Zeige SHA256 für heruntergeladene Dateien (lokale Berechnung)
    add      "NAME" "URL"        Füge eine ISO zum Manifest hinzu (Datei: isos.list)
    help                       Zeige diese Hilfe

Manifeste:
    - isos.list (Hauptliste)
    - isos.d/*.list (zusätzliche Listen, automatisch geladen)

Beispiele:
    $0                      # lädt alle ISOs herunter
    $0 download 3           # lädt ISO mit Index 3
    $0 download "Ubuntu Server" # lädt ISO nach Name
    $0 status               # Status aller ISOs (lokal)
    $0 status --remote      # Status mit Remote-Größenvergleich
    $0 status Ubuntu        # Status für ISO(s) deren Name "Ubuntu" enthält
    $0 list                 # Liste anzeigen
    $0 verify               # SHA256 von vorhandenen ISOs berechnen und anzeigen
    $0 add "My Distro" "https://example.com/my.iso"  # ISO hinzufügen
EOF
}

# Funktion zum Überprüfen der Internetverbindung
check_internet() {
    print_colored "$BLUE" "Überprüfe Internetverbindung..."
    if ping -c 1 -W 2 1.1.1.1 &> /dev/null || ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        log_message "INFO" "Internetverbindung verfügbar"
        return 0
    else
        log_message "ERROR" "Keine Internetverbindung verfügbar"
        print_colored "$RED" "Fehler: Keine Internetverbindung"
        exit 1
    fi
}

# ISO-Definitionen aus Manifesten laden
MANIFEST_FILE="./isos.list"
MANIFEST_DIR="./isos.d"

init_isos() {
    ISOS=()
    local sources=()
    if [ -f "$MANIFEST_FILE" ]; then
        sources+=("$MANIFEST_FILE")
    fi
    if [ -d "$MANIFEST_DIR" ]; then
        # deterministische Reihenfolge
        while IFS= read -r f; do sources+=("$f"); done < <(ls -1 "$MANIFEST_DIR"/*.list 2>/dev/null | sort)
    fi
    if [ ${#sources[@]} -eq 0 ]; then
        print_colored "$YELLOW" "Keine Manifest-Dateien gefunden. Erstelle Standard 'isos.list' oder nutze '$0 add'."
    fi
    # Lesen
    local line
    for src in "${sources[@]}"; do
        while IFS= read -r line || [ -n "$line" ]; do
            # Kommentare/Leerzeilen überspringen
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            # Erwartetes Format: Name|URL
            if [[ "$line" == *"|"* ]]; then
                ISOS+=("$line")
            else
                print_colored "$YELLOW" "Überspringe ungültige Zeile in $src: $line"
            fi
        done < "$src"
    done
}

# Eintrag zur Manifest-Datei hinzufügen (mit Duplikatprüfung)
add_iso_entry() {
    local name="$1"
    local url="$2"
    if [ -z "$name" ] || [ -z "$url" ]; then
        print_colored "$RED" "Nutzung: $0 add \"Name\" \"URL\""
        return 1
    fi
    if [[ "$url" != http://* && "$url" != https://* ]]; then
        print_colored "$RED" "URL muss mit http(s) beginnen"
        return 1
    fi
    mkdir -p "$(dirname "$MANIFEST_FILE")"
    touch "$MANIFEST_FILE"

    # Prüfe auf Duplikate (nach Name ODER URL in allen Quellen)
    init_isos
    for entry in "${ISOS[@]}"; do
        local ename=$(iso_name "$entry")
        local eurl=$(iso_url "$entry")
        if [[ "$ename" == "$name" || "$eurl" == "$url" ]]; then
            print_colored "$YELLOW" "Eintrag existiert bereits (Name oder URL). Nichts zu tun."
            return 0
        fi
    done
    echo "$name|$url" >> "$MANIFEST_FILE"
    print_colored "$GREEN" "Hinzugefügt: $name -> $url in $MANIFEST_FILE"
}

# Hilfsfunktionen für ISO-Daten
iso_name() { echo "$1" | cut -d'|' -f1; }
iso_url()  { echo "$1" | cut -d'|' -f2-; }
basename_from_url() { basename "$1"; }

human_size() {
    # Eingabe: Bytes oder bereits menschenlesbar
    local size_bytes="$1"
    if [[ "$size_bytes" =~ ^[0-9]+$ ]]; then
        awk -v bytes="$size_bytes" 'function human(x){s="BKMGTP";while(x>=1024&&length(s)>1){x/=1024;s=substr(s,2)}return sprintf("%.1f%s",x,substr(s,1,1))} BEGIN{print human(bytes)}'
    else
        echo "$size_bytes"
    fi
}

local_file_path() {
    local url="$1"
    echo "$DOWNLOAD_DIR/$(basename_from_url "$url")"
}

remote_content_length() {
    local url="$1"
    # Versuch via HEAD die Content-Length zu holen
    local cl
    cl=$(curl -sI --connect-timeout "$HEAD_TIMEOUT" --max-time "$HEAD_TIMEOUT" -L "$url" | awk -F': ' 'BEGIN{IGNORECASE=1} tolower($1)=="content-length"{gsub("\r","",$2);print $2; exit}')
    if [[ -n "$cl" && "$cl" =~ ^[0-9]+$ ]]; then
        echo "$cl"
        return 0
    fi
    return 1
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

# Download mit Resume (setzt Range fort, wenn vorhanden)
resume_iso() {
    local name=$1
    local url=$2
    local filename=$(basename "$url")
    local filepath="$DOWNLOAD_DIR/$filename"

    print_colored "$YELLOW" "Resume Download: $name"
    log_message "INFO" "Resume Download von $name: $url"

    local retry_count=0
    while [ $retry_count -lt $MAX_RETRIES ]; do
        if curl -L --connect-timeout $TIMEOUT --max-time 0 -C - -# -o "$filepath" "$url"; then
            print_colored "$GREEN" "✓ Download abgeschlossen/fortgesetzt: $name"
            log_message "SUCCESS" "Resume erfolgreich: $name -> $filepath"
            local filesize=$(ls -lh "$filepath" | awk '{print $5}')
            log_message "INFO" "Dateigröße: $filesize"
            return 0
        else
            retry_count=$((retry_count + 1))
            print_colored "$RED" "✗ Resume fehlgeschlagen: $name (Versuch $retry_count/$MAX_RETRIES)"
            log_message "ERROR" "Resume fehlgeschlagen für $name, Versuch $retry_count/$MAX_RETRIES"
            if [ $retry_count -lt $MAX_RETRIES ]; then
                print_colored "$YELLOW" "Wiederhole in 5 Sekunden..."
                sleep 5
            fi
        fi
    done
    print_colored "$RED" "✗ Alle Versuche fehlgeschlagen für: $name (Resume)"
    log_message "ERROR" "Alle Resume-Versuche fehlgeschlagen für $name"
    return 1
}

# ISOs auflisten
list_isos() {
    init_isos
    local idx=1
    print_colored "$BLUE" "Verfügbare ISOs:"
    for entry in "${ISOS[@]}"; do
        local name=$(iso_name "$entry")
        local url=$(iso_url "$entry")
        echo "  [$idx] $name -> $(basename_from_url "$url")"
        idx=$((idx+1))
    done
    if [ ${#ISOS[@]} -eq 0 ]; then
        print_colored "$YELLOW" "(Keine Einträge gefunden. Füge mit '$0 add "Name" "URL"' neue ISOs hinzu.)"
    fi
}

# Status anzeigen
status_isos() {
    local query="$1"   # kann leer, all, index, name sein
    local with_remote="$2" # true/false
    init_isos
    local idx=1
    local matched=0
    printf "%-4s %-22s %-11s %-10s %-12s\n" "#" "Name" "Status" "Lokal" "Remote"
    printf "%-4s %-22s %-11s %-10s %-12s\n" "----" "----------------------" "-----------" "----------" "------------"
    for entry in "${ISOS[@]}"; do
        local name=$(iso_name "$entry")
        local url=$(iso_url "$entry")
        local file=$(local_file_path "$url")

        # Filter anwenden
        local include=false
        if [[ -z "$query" || "$query" == "all" ]]; then
            include=true
        elif [[ "$query" =~ ^[0-9]+$ ]]; then
            if [ "$idx" -eq "$query" ]; then include=true; fi
        else
            shopt -s nocasematch
            if [[ "$name" == *"$query"* ]]; then include=true; fi
            shopt -u nocasematch
        fi

        if $include; then
            matched=1
            local status
            local local_size="-"
            local remote_size="-"
            if [ -f "$file" ]; then
                status="Vorhanden"
                local_size=$(human_size "$(stat -c %s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)" )
            else
                status="Fehlt"
            fi
            if [[ "$with_remote" == "true" ]]; then
                if rs=$(remote_content_length "$url"); then
                    remote_size=$(human_size "$rs")
                    if [ -f "$file" ]; then
                        # Optional: Vollständigkeitsprüfung
                        local_size_bytes=$(stat -c %s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
                        if [[ "$local_size_bytes" =~ ^[0-9]+$ ]] && [ "$local_size_bytes" -lt "$rs" ]; then
                            status="Teilweise"
                        fi
                    fi
                else
                    remote_size="?"
                fi
            fi
            printf "%-4s %-22s %-11s %-10s %-12s\n" "[$idx]" "${name:0:22}" "$status" "$local_size" "$remote_size"
        fi
        idx=$((idx+1))
    done
    if [ $matched -eq 0 ]; then
        print_colored "$YELLOW" "Keine passenden ISOs für Filter: '$query'"
    fi
}

# SHA256 berechnen/anzeigen
verify_isos() {
    local query="$1"
    init_isos
    local idx=1
    local matched=0
    for entry in "${ISOS[@]}"; do
        local name=$(iso_name "$entry")
        local url=$(iso_url "$entry")
        local file=$(local_file_path "$url")

        local include=false
        if [[ -z "$query" || "$query" == "all" ]]; then
            include=true
        elif [[ "$query" =~ ^[0-9]+$ ]]; then
            if [ "$idx" -eq "$query" ]; then include=true; fi
        else
            shopt -s nocasematch
            if [[ "$name" == *"$query"* ]]; then include=true; fi
            shopt -u nocasematch
        fi

        if $include; then
            matched=1
            if [ -f "$file" ]; then
                print_colored "$BLUE" "SHA256 für $name ($(basename "$file"))"
                if command -v sha256sum >/dev/null 2>&1; then
                    sha256sum "$file"
                else
                    shasum -a 256 "$file" 2>/dev/null || echo "sha256sum/shasum nicht verfügbar"
                fi
            else
                print_colored "$YELLOW" "Datei fehlt: $name"
            fi
        fi
        idx=$((idx+1))
    done
    if [ $matched -eq 0 ]; then
        print_colored "$YELLOW" "Keine passenden ISOs für Filter: '$query'"
    fi
}

# Hauptfunktion
main_download_all() {
    init_isos
    check_internet

    local total_isos=${#ISOS[@]}
    local current=1
    local successful_downloads=0
    local failed_downloads=0

    print_colored "$BLUE" "Insgesamt $total_isos ISOs zum Herunterladen"
    echo

    for iso_entry in "${ISOS[@]}"; do
        local name=$(iso_name "$iso_entry")
        local url=$(iso_url "$iso_entry")
        print_colored "$BLUE" "[$current/$total_isos] Lade herunter: $name"
        if download_iso "$name" "$url"; then
            successful_downloads=$((successful_downloads + 1))
        else
            failed_downloads=$((failed_downloads + 1))
        fi
        current=$((current + 1))
        echo
    done

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

    if [ $successful_downloads -gt 0 ]; then
        print_colored "$BLUE" "Heruntergeladene Dateien:"
        ls -lh "$DOWNLOAD_DIR"/ | grep -v "^total" | while read -r line; do
            print_colored "$GREEN" "  $line"
        done
    fi
}

main() {
    print_colored "$BLUE" "════════════════════════════════════════"
    print_colored "$BLUE" "       ISO Download Script gestartet     "
    print_colored "$BLUE" "════════════════════════════════════════"

    log_message "INFO" "ISO Download Script gestartet"
    log_message "INFO" "Log-Datei: $LOG_FILE"
    log_message "INFO" "Download-Verzeichnis: $DOWNLOAD_DIR"

    local cmd="$1"; shift || true

    case "$cmd" in
        ""|download)
            # optionales Argument: all|INDEX|NAME
            if [ "$cmd" = "download" ]; then
                arg="$1"; shift || true
            else
                arg="all"
            fi
            if [[ -z "$arg" || "$arg" == "all" ]]; then
                main_download_all
            else
                init_isos
                check_internet
                local idx=1; local matched=0
                for entry in "${ISOS[@]}"; do
                    local name=$(iso_name "$entry")
                    local url=$(iso_url "$entry")
                    local include=false
                    if [[ "$arg" =~ ^[0-9]+$ ]]; then
                        if [ "$idx" -eq "$arg" ]; then include=true; fi
                    else
                        shopt -s nocasematch
                        if [[ "$name" == *"$arg"* ]]; then include=true; fi
                        shopt -u nocasematch
                    fi
                    if $include; then
                        matched=1
                        download_iso "$name" "$url" || true
                    fi
                    idx=$((idx+1))
                done
                if [ $matched -eq 0 ]; then
                    print_colored "$YELLOW" "Keine passende ISO gefunden für: '$arg'"
                    list_isos
                fi
            fi
            ;;
        status)
            local with_remote=false
            local q=""
            for a in "$@"; do
                case "$a" in
                    --remote) with_remote=true ;;
                    *) q="$a" ;;
                esac
            done
            status_isos "$q" "$with_remote"
            ;;
        list)
            list_isos
            ;;
        add)
            # Nutzung: add "Name" "URL"
            add_iso_entry "$1" "$2"
            ;;
        verify)
            verify_isos "$1"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_colored "$YELLOW" "Unbekanntes Kommando: '$cmd'"
            show_usage
            exit 1
            ;;
    esac
}

# Script starten
main "$@"