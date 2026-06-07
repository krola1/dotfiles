#!/usr/bin/env bash
#
# Formål:
#   Fjerne Timeshift fra et Arch/Archinstall-system med Btrfs, og sette opp
#   et mer Arch-vennlig rollback-oppsett med Snapper.
#
# Hva scriptet gjør:
#   1. Stopper/deaktiverer eventuelle Timeshift-timere.
#   2. Avinstallerer installerte Timeshift-pakker hvis de finnes.
#   3. Verifiserer at rotfilsystemet / er Btrfs.
#   4. Installerer Snapper, snap-pac og btrfs-progs.
#   5. Lager en Snapper-konfig for / med eget top-level Btrfs-subvolume
#      @snapshots montert på /.snapshots.
#   6. Aktiverer Snapper sine timeline- og cleanup-timere.
#   7. Aktiverer automatiske pacman-snapshots via snap-pac.
#   8. Installerer og aktiverer grub-btrfs bare hvis GRUB ser ut til å være i bruk.
#
# Om ytelse (viktig for "tar pacman evigheter pga. snapshot?"):
#   - Btrfs-snapshots er copy-on-write. snap-pac kopierer INGEN data; den lager
#     bare et referansepunkt. Dette tar millisekunder uansett hvor full disken er,
#     så pre/post-snapshot ved pacman gjør IKKE installasjon treg.
#   - Det som kan gjøre slike oppsett tregt er grub-btrfs som regenererer
#     boot-menyen. Derfor:
#       * grub-btrfsd kjører asynkront i bakgrunnen (inotify) og blokkerer ikke pacman.
#       * Vi skrur AV os-prober (GRUB_DISABLE_OS_PROBER=true) – den vanligste
#         kilden til treg grub-mkconfig.
#       * Vi begrenser antall snapshots i grub-menyen (GRUB_BTRFS_LIMIT).
#       * Vi setter ingen grub-mkconfig pacman-hook (det er nettopp slike hooks
#         som gir "pacman henger i 30 sek").
#       * EMPTY_PRE_POST_CLEANUP rydder bort tomme pre/post-par.
#
# Viktig:
#   - Scriptet snapshotter systemet (/), ikke /home.
#   - Det sletter IKKE gamle Timeshift-snapshots automatisk, siden det kan fjerne
#     siste fungerende rollback-punkt. Se egen valgfri seksjon nederst.
#   - Kjør dette fra normal boot, ikke fra en snapshot-boot.
#   - Les gjennom før kjøring.
#
# Bruk:
#   chmod +x setup-snapper-rollback.sh
#   ./setup-snapper-rollback.sh

set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

log() {
  printf '\n==> %s\n' "$*"
}

warn() {
  printf '\nADVARSEL: %s\n' "$*" >&2
}

die() {
  printf '\nFEIL: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Mangler kommandoen: $1"
}

set_snapper_key() {
  local key="$1"
  local value="$2"
  local cfg="/etc/snapper/configs/root"

  [[ -f "$cfg" ]] || die "Fant ikke $cfg"

  if grep -qE "^${key}=" "$cfg"; then
    $SUDO sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$cfg"
  else
    printf '%s="%s"\n' "$key" "$value" | $SUDO tee -a "$cfg" >/dev/null
  fi
}

# Generisk hjelper for enkle KEY=VALUE-filer (f.eks. /etc/default/grub og
# /etc/default/grub-btrfs/config). Erstatter også utkommenterte linjer (#KEY=).
set_kv() {
  local file="$1"
  local key="$2"
  local value="$3"

  [[ -f "$file" ]] || return 1

  if grep -qE "^#?${key}=" "$file"; then
    $SUDO sed -i "s|^#\?${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" | $SUDO tee -a "$file" >/dev/null
  fi
}

strip_btrfs_subvol_options() {
  local opts="$1"

  # Fjern subvol/subvolid fra mount options, men behold f.eks. compress=zstd:3,ssd,space_cache=v2.
  printf '%s' "$opts" \
    | tr ',' '\n' \
    | grep -vE '^(subvol|subvolid)=' \
    | paste -sd, -
}

unit_exists() {
  systemctl list-unit-files "$1" >/dev/null 2>&1
}

log "Sjekker grunnleggende krav"
require_cmd pacman
require_cmd findmnt
require_cmd sed
require_cmd awk
require_cmd grep
require_cmd tee
require_cmd systemctl
require_cmd blkid

ROOT_FSTYPE="$(findmnt -no FSTYPE /)"
[[ "$ROOT_FSTYPE" == "btrfs" ]] || die "/ er ikke montert som Btrfs. Fant: $ROOT_FSTYPE"

ROOT_SOURCE_RAW="$(findmnt -no SOURCE /)"
ROOT_DEV="${ROOT_SOURCE_RAW%%[*}"
# Kjør blkid med rettigheter – som vanlig bruker kan UUID mangle for enkelte
# enheter (særlig LUKS/device-mapper).
ROOT_UUID="$($SUDO blkid -s UUID -o value "$ROOT_DEV" 2>/dev/null || true)"
[[ -n "$ROOT_UUID" ]] || die "Klarte ikke å finne UUID for $ROOT_DEV"

ROOT_OPTS="$(findmnt -no OPTIONS / | tr -d ' ')"
ROOT_SUBVOL="$(printf '%s' "$ROOT_OPTS" | tr ',' '\n' | awk -F= '$1=="subvol"{print $2; exit}')"

log "Fant Btrfs-root"
printf 'Root source: %s\n' "$ROOT_SOURCE_RAW"
printf 'Btrfs device: %s\n' "$ROOT_DEV"
printf 'Btrfs UUID:   %s\n' "$ROOT_UUID"
printf 'Root subvol:  %s\n' "${ROOT_SUBVOL:-ukjent}"

if [[ "${ROOT_SUBVOL:-}" != "@" ]]; then
  warn "Root-subvolume ser ikke ut til å være '@'. Scriptet kan fortsatt fungere, men oppsettet ditt avviker fra forventningen."
fi

log "Stopper/deaktiverer mulige Timeshift-timere"
for unit in \
  timeshift.timer \
  timeshift-boot.timer \
  timeshift-hourly.timer \
  timeshift-daily.timer \
  timeshift-weekly.timer \
  timeshift-monthly.timer; do
  if unit_exists "$unit"; then
    $SUDO systemctl disable --now "$unit" || true
  fi
done

log "Avinstallerer Timeshift-pakker hvis de er installert"
TIMESHIFT_PKGS=()
for pkg in timeshift timeshift-autosnap timeshift-systemd-timer; do
  if pacman -Qq "$pkg" >/dev/null 2>&1; then
    TIMESHIFT_PKGS+=("$pkg")
  fi
done

if (( ${#TIMESHIFT_PKGS[@]} > 0 )); then
  $SUDO pacman -Rns --noconfirm "${TIMESHIFT_PKGS[@]}"
else
  log "Ingen Timeshift-pakker funnet via pacman"
fi

log "Installerer Snapper-oppsettet"
$SUDO pacman -Syu --needed --noconfirm snapper snap-pac btrfs-progs

log "Tar backup av /etc/fstab"
FSTAB_BACKUP="/etc/fstab.backup.snapper-$(date +%Y%m%d-%H%M%S)"
$SUDO cp -a /etc/fstab "$FSTAB_BACKUP"
printf 'Backup laget: %s\n' "$FSTAB_BACKUP"

log "Sørger for top-level Btrfs-subvolume @snapshots"
TMP_TOP="$(mktemp -d)"
cleanup_tmp_top() {
  if mountpoint -q "$TMP_TOP"; then
    $SUDO umount "$TMP_TOP" || true
  fi
  rmdir "$TMP_TOP" 2>/dev/null || true
}
trap cleanup_tmp_top EXIT

$SUDO mount -o subvolid=5 "$ROOT_DEV" "$TMP_TOP"

if ! $SUDO btrfs subvolume list "$TMP_TOP" | awk '{print $NF}' | grep -qx '@snapshots'; then
  $SUDO btrfs subvolume create "$TMP_TOP/@snapshots"
else
  log "@snapshots finnes allerede"
fi

log "Lager Snapper-konfig for root hvis den ikke finnes"
if $SUDO snapper -c root get-config >/dev/null 2>&1; then
  log "Snapper-konfig 'root' finnes allerede; overskriver den ikke"
else
  $SUDO snapper -c root create-config /
fi

log "Monterer @snapshots på /.snapshots"
if mountpoint -q /.snapshots; then
  $SUDO umount /.snapshots
fi

if $SUDO btrfs subvolume show /.snapshots >/dev/null 2>&1; then
  # Dette er typisk subvolumet Snapper laget automatisk under @.
  # Det fjernes slik at vi kan bruke top-level @snapshots i stedet.
  $SUDO btrfs subvolume delete /.snapshots
elif [[ -d /.snapshots ]]; then
  $SUDO rmdir /.snapshots 2>/dev/null || warn "/.snapshots finnes og er ikke tom. Prøver å fortsette."
fi

$SUDO mkdir -p /.snapshots

SNAPSHOT_OPTS_BASE="$(strip_btrfs_subvol_options "$ROOT_OPTS")"
if [[ -n "$SNAPSHOT_OPTS_BASE" ]]; then
  SNAPSHOT_OPTS="${SNAPSHOT_OPTS_BASE},subvol=@snapshots"
else
  SNAPSHOT_OPTS="subvol=@snapshots"
fi

if ! grep -Eq '[[:space:]]/\.snapshots[[:space:]]+btrfs[[:space:]]' /etc/fstab; then
  printf 'UUID=%s /.snapshots btrfs %s 0 0\n' "$ROOT_UUID" "$SNAPSHOT_OPTS" | $SUDO tee -a /etc/fstab >/dev/null
else
  log "/.snapshots finnes allerede i /etc/fstab; endrer ikke eksisterende linje"
fi

$SUDO mount /.snapshots
$SUDO chmod 750 /.snapshots

# Verifiser at /.snapshots faktisk bruker top-level @snapshots, slik at oppsettet
# også er riktig ved neste boot (via fstab).
log "Verifiserer at /.snapshots bruker top-level @snapshots"
SNAP_SUBVOL="$(findmnt -no OPTIONS /.snapshots | tr ',' '\n' | awk -F= '$1=="subvol"{print $2; exit}')"
case "${SNAP_SUBVOL:-}" in
  *@snapshots) log "/.snapshots -> subvol=${SNAP_SUBVOL} (OK)" ;;
  *) warn "/.snapshots bruker subvol=${SNAP_SUBVOL:-ukjent}, forventet @snapshots. Sjekk $FSTAB_BACKUP vs /etc/fstab." ;;
esac

log "Setter fornuftige Snapper-retention-verdier"
# Timeline gir periodiske snapshots i tillegg til snap-pac sine pacman-snapshots.
# Vil du holde antallet (og dermed grub-menyen) minst mulig, kan du sette
# TIMELINE_CREATE til "no" og la snap-pac stå for snapshots ved pacman.
set_snapper_key TIMELINE_CREATE yes
set_snapper_key TIMELINE_CLEANUP yes
set_snapper_key TIMELINE_LIMIT_HOURLY 10
set_snapper_key TIMELINE_LIMIT_DAILY 7
set_snapper_key TIMELINE_LIMIT_WEEKLY 4
set_snapper_key TIMELINE_LIMIT_MONTHLY 3
set_snapper_key TIMELINE_LIMIT_YEARLY 0

set_snapper_key NUMBER_CLEANUP yes
set_snapper_key NUMBER_LIMIT 20
set_snapper_key NUMBER_LIMIT_IMPORTANT 10

# Holder snapshot-antallet nede: tomme pre/post-par (pacman-kjøringer uten
# faktiske endringer) ryddes bort.
set_snapper_key EMPTY_PRE_POST_CLEANUP yes
set_snapper_key EMPTY_PRE_POST_MIN_AGE 1800

# Lar brukere i wheel lese Snapper-status via verktøy som btrfs-assistant.
# Fjern dette hvis du vil ha root-only.
set_snapper_key ALLOW_GROUPS wheel
set_snapper_key SYNC_ACL yes

log "Aktiverer Snapper-timere"
for unit in snapper-timeline.timer snapper-cleanup.timer; do
  if unit_exists "$unit"; then
    $SUDO systemctl enable --now "$unit"
  else
    warn "Fant ikke systemd-unit: $unit"
  fi
done

if unit_exists snapper-boot.timer; then
  $SUDO systemctl enable --now snapper-boot.timer
fi

log "Lager første manuelle snapshot"
$SUDO snapper -c root create --description "manual: initial snapper setup" --userdata "important=yes"

log "Sjekker om GRUB er i bruk"
if [[ -d /boot/grub ]] || command -v grub-mkconfig >/dev/null 2>&1; then
  log "GRUB ser ut til å finnes. Installerer grub-btrfs og inotify-tools."
  $SUDO pacman -S --needed --noconfirm grub-btrfs inotify-tools

  # Begrens antall snapshots i grub-menyen. Færre oppføringer = raskere
  # regenerering og ryddigere boot-meny.
  GRUB_BTRFS_CFG="/etc/default/grub-btrfs/config"
  if [[ -f "$GRUB_BTRFS_CFG" ]]; then
    set_kv "$GRUB_BTRFS_CFG" GRUB_BTRFS_LIMIT '"15"'
  else
    warn "Fant ikke $GRUB_BTRFS_CFG; hopper over GRUB_BTRFS_LIMIT."
  fi

  # Hold grub-mkconfig og grub-btrfs-regenerering rask: ikke skann etter andre OS.
  if [[ -f /etc/default/grub ]]; then
    set_kv /etc/default/grub GRUB_DISABLE_OS_PROBER true
  else
    warn "Fant ikke /etc/default/grub; hopper over GRUB_DISABLE_OS_PROBER."
  fi

  if unit_exists grub-btrfsd.service; then
    $SUDO systemctl enable --now grub-btrfsd.service
  else
    warn "Fant ikke grub-btrfsd.service etter installasjon"
  fi

  if command -v grub-mkconfig >/dev/null 2>&1 && [[ -d /boot/grub ]]; then
    $SUDO grub-mkconfig -o /boot/grub/grub.cfg
  else
    warn "Fant ikke /boot/grub eller grub-mkconfig. Hopper over grub.cfg-generering."
  fi
else
  warn "GRUB ble ikke funnet. Hopper over grub-btrfs."
  warn "Du får fortsatt Snapper + snap-pac, men ikke bootbare snapshots i GRUB-meny."
fi

log "Status"
$SUDO snapper -c root list
systemctl --no-pager --full status snapper-timeline.timer snapper-cleanup.timer || true
if unit_exists grub-btrfsd.service; then
  systemctl --no-pager --full status grub-btrfsd.service || true
fi

cat <<'EOF'

Ferdig.

Neste gang du kjører pacman, skal snap-pac lage pre/post snapshots automatisk, for eksempel:
  sudo pacman -Syu

Merk: snapshot-delen er copy-on-write og tar millisekunder – den gjør ikke pacman
treg. Hvis du noen gang opplever treghet, er det som regel grub-mkconfig/os-prober,
ikke selve snapshotten.

Nyttige kommandoer:
  sudo snapper -c root list
  sudo snapper -c root status <før-id>..<etter-id>
  sudo snapper -c root diff <før-id>..<etter-id>

Slik ruller du tilbake (kort):
  A) Fra et fungerende system:
       sudo snapper -c root list                 # finn ønsket snapshot-ID
       sudo snapper -c root rollback <id>        # lager nytt read-write subvolume av snapshot
       sudo reboot
  B) Hvis systemet ikke booter:
       - Velg snapshot fra GRUB-undermenyen "Arch Linux snapshots" (read-only boot).
       - Når du er inne, kjør:
           sudo snapper -c root rollback
           sudo reboot

Valgfritt: slett gamle Timeshift-snapshots manuelt senere
  1. Sjekk først:
       sudo btrfs subvolume list /
       sudo du -h -d 2 /run/timeshift 2>/dev/null || true
  2. Ikke slett noe du fortsatt vil kunne rulle tilbake til.

EOF