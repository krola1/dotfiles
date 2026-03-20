#!/usr/bin/env python3
"""
Generer input-delen av en MoltenGamepad gendev .cfg-fil fra en evdev-enhet.

Bruk:
    sudo python3 scripts/generate-gendev-cfg.py

Scriptet:
  1. Lister opp alle evdev-enheter (/dev/input/event*)
  2. Lar brukeren velge en enhet
  3. Leser capabilities (knapper, akser, hats)
  4. Skriver ut en .cfg-fil med match-header, driverinnstillinger og
     event-definisjoner – uten aliases (det settes opp manuelt etterpå)

Krever: python-evdev  (pip install evdev  eller  pacman -S python-evdev)
"""

import sys

try:
    import evdev
    from evdev import ecodes
except ImportError:
    print("❌ Mangler python-evdev. Installer med:")
    print("     pip install evdev")
    print("   eller:")
    print("     sudo pacman -S python-evdev")
    sys.exit(1)


# ── Hjelpefunksjoner ─────────────────────────────────────────────────────────


def list_devices():
    """Returner en sortert liste over tilgjengelige evdev-enheter."""
    devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
    devices.sort(key=lambda d: d.path)
    return devices


def select_device(devices):
    """La brukeren velge en enhet fra listen. Returnerer valgt InputDevice."""
    print("\n📋 Tilgjengelige evdev-enheter:\n")
    for i, dev in enumerate(devices):
        print(f"  {i:3d})  {dev.path}  –  {dev.name}")
    print()

    while True:
        try:
            raw = input("Velg enhet (nummer): ").strip()
            idx = int(raw)
            if 0 <= idx < len(devices):
                return devices[idx]
            print(f"  ⚠️  Ugyldig valg – skriv et tall mellom 0 og {len(devices) - 1}")
        except ValueError:
            print("  ⚠️  Skriv inn et gyldig heltall")
        except (KeyboardInterrupt, EOFError):
            print("\n\nAvbrutt.")
            sys.exit(0)


def format_hex(val):
    """Formater et heltall som firesifret hex uten 0x-prefiks."""
    return f"{val:04x}"


# ── Capability-lesing ────────────────────────────────────────────────────────


def capability_name(etype, ecode):
    """Returner det lesbare evdev-navnet for en event-kode, i lowercase.

    For ukjente koder returneres key(<kode>) eller abs(<kode>).
    """
    if etype == ecodes.EV_KEY:
        name = ecodes.KEY.get(ecode) or ecodes.BTN.get(ecode)
        if name is None:
            return f"key({ecode})"
        # ecodes kan gi en liste (f.eks. BTN_A / BTN_SOUTH) – bruk første
        if isinstance(name, list):
            name = name[0]
        return name.lower()

    if etype == ecodes.EV_ABS:
        name = ecodes.ABS.get(ecode)
        if name is None:
            return f"abs({ecode})"
        if isinstance(name, list):
            name = name[0]
        return name.lower()

    return None


def gather_events(device):
    """Les capabilities og returner to lister: (keys, abs_axes).

    Hver entry er (evdev_name, description).
    """
    caps = device.capabilities(verbose=False)

    keys = []
    abs_axes = []

    # EV_KEY (knapper)
    for code in caps.get(ecodes.EV_KEY, []):
        name = capability_name(ecodes.EV_KEY, code)
        if name:
            keys.append(name)

    # EV_ABS (akser og hats)
    for code_info in caps.get(ecodes.EV_ABS, []):
        # code_info er (code, AbsInfo) eller bare code
        code = code_info[0] if isinstance(code_info, tuple) else code_info
        name = capability_name(ecodes.EV_ABS, code)
        if name:
            abs_axes.append(name)

    return keys, abs_axes


# ── Generer .cfg-innhold ─────────────────────────────────────────────────────


def make_internal_name(evdev_name):
    """Lag et kort internt navn fra evdev-navnet.

    Fjerner prefiks (btn_, abs_, key_) og returnerer resten.
    Eksempel: btn_south -> south, abs_hat0x -> hat0x
    """
    for prefix in ("btn_", "abs_", "key_"):
        if evdev_name.startswith(prefix):
            return evdev_name[len(prefix):]
    # For key(123)-stil, behold som det er
    return evdev_name


def categorize_keys(keys):
    """Del knapper inn i kategorier for lesbar output."""
    face = []
    shoulder = []
    trigger = []
    stick = []
    dpad = []
    menu = []
    other = []

    for k in keys:
        kl = k.lower()
        if kl in ("btn_south", "btn_east", "btn_north", "btn_west",
                   "btn_a", "btn_b", "btn_x", "btn_y"):
            face.append(k)
        elif kl in ("btn_tl", "btn_tr"):
            shoulder.append(k)
        elif kl in ("btn_tl2", "btn_tr2"):
            trigger.append(k)
        elif kl in ("btn_thumbl", "btn_thumbr"):
            stick.append(k)
        elif "dpad" in kl:
            dpad.append(k)
        elif kl in ("btn_start", "btn_select", "btn_mode"):
            menu.append(k)
        else:
            other.append(k)

    return [
        ("Ansiktsknapper", face),
        ("Skulderknapper", shoulder),
        ("Trigger-knapper (digital)", trigger),
        ("Stikk-knapper", stick),
        ("D-pad-knapper", dpad),
        ("Meny-knapper", menu),
        ("Andre knapper", other),
    ]


def categorize_axes(axes):
    """Del akser inn i kategorier for lesbar output."""
    sticks = []
    triggers = []
    hats = []
    other = []

    for a in axes:
        al = a.lower()
        if al in ("abs_x", "abs_y", "abs_rx", "abs_ry"):
            sticks.append(a)
        elif al in ("abs_z", "abs_rz"):
            triggers.append(a)
        elif "hat" in al:
            hats.append(a)
        else:
            other.append(a)

    return [
        ("Stikk-akser", sticks),
        ("Trigger-akser (analog)", triggers),
        ("D-pad / hat-akser", hats),
        ("Andre akser", other),
    ]


def generate_cfg(device, keys, abs_axes):
    """Generer en MoltenGamepad gendev .cfg-fil som streng."""
    info = device.info
    vendor = format_hex(info.vendor)
    product = format_hex(info.product)
    version = format_hex(info.version)

    # Lag et fornuftig drivernavn fra enhetsnavnet
    safe_name = (
        device.name.lower()
        .replace(" ", "_")
        .replace("-", "_")
        .replace("/", "_")
        .replace("(", "")
        .replace(")", "")
    )
    # Begrens lengden
    if len(safe_name) > 30:
        safe_name = safe_name[:30]

    lines = []

    # ── Header ──
    lines.append(f"# {device.name}")
    lines.append(f"# vendor={vendor} product={product} version={version}")
    lines.append(
        f'[name="{device.name}" vendor={vendor} product={product}]'
    )
    lines.append("")

    # ── Driverinnstillinger ──
    lines.append(f'name    = "{safe_name}"')
    lines.append(f'devname = "pad"')
    lines.append("")
    lines.append('exclusive = "true"')
    lines.append('change_permissions = "false"')
    lines.append('rumble = "false"')
    lines.append("")

    # ── Event-definisjoner ──

    # Knapper
    key_categories = categorize_keys(keys)
    for label, group in key_categories:
        if not group:
            continue
        lines.append(f"# {label}")
        for k in group:
            internal = make_internal_name(k)
            padded_key = k.ljust(12)
            lines.append(f'{padded_key} = "{internal}",  "{k}"')
        lines.append("")

    # Akser
    axis_categories = categorize_axes(abs_axes)
    for label, group in axis_categories:
        if not group:
            continue
        lines.append(f"# {label}")
        for a in group:
            internal = make_internal_name(a)
            padded_axis = a.ljust(12)
            lines.append(f'{padded_axis} = "{internal}",  "{a}"')
        lines.append("")

    # ── Aliaser (tom seksjon for manuell utfylling) ──
    lines.append("# ── Aliases (fyll inn manuelt) ────────────────────────────")
    lines.append("# alias first  <ditt_knappenavn>")
    lines.append("# alias second <ditt_knappenavn>")
    lines.append("# ... se dokumentasjonen for alle tilgjengelige alias-navn")
    lines.append("")

    return "\n".join(lines)


# ── Hovedprogram ─────────────────────────────────────────────────────────────


def main():
    print("🎮 MoltenGamepad gendev .cfg-generator")
    print("   Genererer input-delen av en gendev-konfigurasjon fra evdev.\n")

    # 1. List enheter
    devices = list_devices()
    if not devices:
        print("❌ Ingen evdev-enheter funnet. Kjør med sudo?")
        sys.exit(1)

    # 2. Velg enhet
    device = select_device(devices)
    print(f"\n✅ Valgt: {device.name}  ({device.path})")

    # 3. Les capabilities
    keys, abs_axes = gather_events(device)
    print(f"   Fant {len(keys)} knapper og {len(abs_axes)} akser.\n")

    if not keys and not abs_axes:
        print("⚠️  Ingen knapper eller akser funnet på denne enheten.")
        sys.exit(1)

    # 4. Generer .cfg
    cfg = generate_cfg(device, keys, abs_axes)

    print("# " + "─" * 68)
    print("# Generert gendev-konfigurasjon – kopier til")
    print("#   ~/.config/moltengamepad/gendevices/<navn>.cfg")
    print("# Husk å legge til aliases manuelt etterpå!")
    print("# " + "─" * 68)
    print()
    print(cfg)


if __name__ == "__main__":
    main()
