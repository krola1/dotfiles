#!/usr/bin/env bash
set -Eeuo pipefail

# Standard: scan hele root-filsystemet.
# Kjør f.eks.: sudo ./clamav_scan.sh /home
SCAN_TARGET="${1:-/}"

LOG_DIR="/var/log/clamav-manual"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/scan-$TIMESTAMP.log"
QUARANTINE_DIR="/var/quarantine/clamav-$TIMESTAMP"

mkdir -p "$LOG_DIR" "$QUARANTINE_DIR"
chmod 700 "$QUARANTINE_DIR"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Kjør scriptet med sudo, ellers får ikke ClamAV lest alle filer."
  echo "Eksempel: sudo $0 /"
  exit 1
fi

echo "== ClamAV scan startet: $(date)" | tee -a "$LOG_FILE"
echo "Scanner: $SCAN_TARGET" | tee -a "$LOG_FILE"
echo "Logg: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Karantene: $QUARANTINE_DIR" | tee -a "$LOG_FILE"
echo | tee -a "$LOG_FILE"

echo "== Oppdaterer ClamAV-pakken hvis mulig..." | tee -a "$LOG_FILE"

if command -v apt-get >/dev/null 2>&1; then
  apt-get update | tee -a "$LOG_FILE"
  apt-get install -y clamav clamav-freshclam | tee -a "$LOG_FILE"
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y clamav clamav-update | tee -a "$LOG_FILE"
  dnf upgrade -y clamav clamav-update | tee -a "$LOG_FILE"
elif command -v yum >/dev/null 2>&1; then
  yum install -y clamav clamav-update | tee -a "$LOG_FILE"
  yum update -y clamav clamav-update | tee -a "$LOG_FILE"
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm clamav | tee -a "$LOG_FILE"
elif command -v zypper >/dev/null 2>&1; then
  zypper --non-interactive install clamav | tee -a "$LOG_FILE"
  zypper --non-interactive update clamav | tee -a "$LOG_FILE"
else
  echo "Fant ikke støttet pakkebehandler. Hopper over pakkeoppdatering." | tee -a "$LOG_FILE"
fi

echo | tee -a "$LOG_FILE"
echo "== Oppdaterer virusdefinisjoner med freshclam..." | tee -a "$LOG_FILE"

# På noen distroer kjører freshclam allerede som tjeneste og kan låse databasen.
if ! freshclam --stdout 2>&1 | tee -a "$LOG_FILE"; then
  echo "freshclam feilet, ofte fordi tjenesten allerede kjører. Prøver å fortsette med eksisterende database." | tee -a "$LOG_FILE"
fi

echo | tee -a "$LOG_FILE"
echo "== Starter scan..." | tee -a "$LOG_FILE"

clamscan \
  --recursive=yes \
  --infected \
  --bell \
  --log="$LOG_FILE" \
  --move="$QUARANTINE_DIR" \
  --exclude-dir='^/proc' \
  --exclude-dir='^/sys' \
  --exclude-dir='^/dev' \
  --exclude-dir='^/run' \
  --exclude-dir='^/var/quarantine' \
  "$SCAN_TARGET"

SCAN_EXIT=$?

echo | tee -a "$LOG_FILE"
echo "== Ferdig: $(date)" | tee -a "$LOG_FILE"

case "$SCAN_EXIT" in
0)
  echo "Ingen trusler funnet." | tee -a "$LOG_FILE"
  ;;
1)
  echo "Trusler funnet. Sjekk karantene: $QUARANTINE_DIR" | tee -a "$LOG_FILE"
  ;;
*)
  echo "Scan feilet eller ble avbrutt. Sjekk logg: $LOG_FILE" | tee -a "$LOG_FILE"
  ;;
esac

exit "$SCAN_EXIT"
