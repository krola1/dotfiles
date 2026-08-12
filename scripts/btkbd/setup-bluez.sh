#!/usr/bin/env bash
# Tynn wrapper rundt btkbd.py --setup, slik at det bare finnes én
# implementasjon av oppsettet.
#
#   sudo ./setup-bluez.sh          konfigurer
#   sudo ./setup-bluez.sh --undo   reverser

set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

if [[ "${1:-}" == "--undo" ]]; then
    exec python3 ./btkbd.py --setup --undo
fi
exec python3 ./btkbd.py --setup "$@"
