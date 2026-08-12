#!/usr/bin/env python3
"""
btkbd - gjør en Linux-laptop til et Bluetooth-tastatur + mus.

Registrerer en HID-profil (UUID 0x1124) hos BlueZ, lytter på L2CAP PSM 17/19,
leser tastatur/mus/touchpad via evdev og videresender som HID input reports.

Krever root (L2CAP PSM < 4096, /dev/input, EVIOCGRAB) og at input-pluginet
i bluetoothd er deaktivert. Se README.md.

Bruk:
    sudo ./btkbd.py --list                  # vis input-enheter
    sudo ./btkbd.py                         # start, vent på tilkobling
    sudo ./btkbd.py --connect AA:BB:CC:DD:EE:FF   # koble ut mot paret vert
"""

from __future__ import annotations

import argparse
import asyncio
import errno
import os
import queue
import signal
import socket
import struct
import sys
import threading
import time

# --------------------------------------------------------------------------
# Konstanter
# --------------------------------------------------------------------------

HID_UUID = "00001124-0000-1000-8000-00805f9b34fb"
PROFILE_PATH = "/org/bluez/btkbd"
AGENT_PATH = "/org/bluez/btkbd/agent"

PSM_CTRL = 17  # 0x11
PSM_INTR = 19  # 0x13

BDADDR_ANY = "00:00:00:00:00:00"

# HIDP transaksjonstyper (høy nibbel i første byte)
HIDP_HANDSHAKE = 0x00
HIDP_HID_CONTROL = 0x10
HIDP_GET_REPORT = 0x40
HIDP_SET_REPORT = 0x50
HIDP_GET_PROTOCOL = 0x60
HIDP_SET_PROTOCOL = 0x70
HIDP_DATA = 0xA0

HS_SUCCESSFUL = 0x00
HS_ERR_UNSUPPORTED = 0x03

RTYPE_INPUT = 0x01

KEYBOARD_REPORT_ID = 1
MOUSE_REPORT_ID = 2

# --------------------------------------------------------------------------
# HID report descriptor: tastatur (ID 1) + mus med 5 knapper og hjul (ID 2)
# --------------------------------------------------------------------------

REPORT_DESCRIPTOR = bytes([
    # ---- Tastatur ----
    0x05, 0x01,              # Usage Page (Generic Desktop)
    0x09, 0x06,              # Usage (Keyboard)
    0xA1, 0x01,              # Collection (Application)
    0x85, KEYBOARD_REPORT_ID,
    0x05, 0x07,              #   Usage Page (Keyboard/Keypad)
    0x19, 0xE0,              #   Usage Min (LeftControl)
    0x29, 0xE7,              #   Usage Max (RightGUI)
    0x15, 0x00, 0x25, 0x01,
    0x75, 0x01, 0x95, 0x08,
    0x81, 0x02,              #   Input (Data,Var,Abs) - modifiers
    0x95, 0x01, 0x75, 0x08,
    0x81, 0x01,              #   Input (Const) - reservert byte
    0x95, 0x05, 0x75, 0x01,  #   LED-utgang
    0x05, 0x08, 0x19, 0x01, 0x29, 0x05,
    0x91, 0x02,              #   Output (Data,Var,Abs)
    0x95, 0x01, 0x75, 0x03,
    0x91, 0x01,              #   Output (Const) - padding
    0x95, 0x06, 0x75, 0x08,
    0x15, 0x00, 0x26, 0xFF, 0x00,
    0x05, 0x07, 0x19, 0x00, 0x2A, 0xFF, 0x00,
    0x81, 0x00,              #   Input (Data,Array) - 6 samtidige taster
    0xC0,                    # End Collection

    # ---- Mus ----
    0x05, 0x01,              # Usage Page (Generic Desktop)
    0x09, 0x02,              # Usage (Mouse)
    0xA1, 0x01,              # Collection (Application)
    0x85, MOUSE_REPORT_ID,
    0x09, 0x01,              #   Usage (Pointer)
    0xA1, 0x00,              #   Collection (Physical)
    0x05, 0x09,              #     Usage Page (Button)
    0x19, 0x01, 0x29, 0x05,
    0x15, 0x00, 0x25, 0x01,
    0x75, 0x01, 0x95, 0x05,
    0x81, 0x02,              #     Input - 5 knapper
    0x75, 0x03, 0x95, 0x01,
    0x81, 0x01,              #     padding
    0x05, 0x01,              #     Usage Page (Generic Desktop)
    0x09, 0x30, 0x09, 0x31,  #     X, Y
    0x16, 0x01, 0x80,        #     Logical Min (-32767)
    0x26, 0xFF, 0x7F,        #     Logical Max (32767)
    0x75, 0x10, 0x95, 0x02,
    0x81, 0x06,              #     Input (Data,Var,Rel)
    0x09, 0x38,              #     Wheel
    0x15, 0x81, 0x25, 0x7F,
    0x75, 0x08, 0x95, 0x01,
    0x81, 0x06,
    0x05, 0x0C,              #     Usage Page (Consumer)
    0x0A, 0x38, 0x02,        #     AC Pan (horisontal scroll)
    0x15, 0x81, 0x25, 0x7F,
    0x75, 0x08, 0x95, 0x01,
    0x81, 0x06,
    0xC0,                    #   End Collection
    0xC0,                    # End Collection
])


def sdp_record(name: str) -> str:
    """Bygger SDP-posten BlueZ publiserer for HID-profilen."""
    desc_hex = REPORT_DESCRIPTOR.hex()
    return f"""<?xml version="1.0" encoding="UTF-8" ?>
<record>
  <attribute id="0x0001">
    <sequence><uuid value="0x1124" /></sequence>
  </attribute>
  <attribute id="0x0004">
    <sequence>
      <sequence>
        <uuid value="0x0100" />
        <uint16 value="0x0011" />
      </sequence>
      <sequence><uuid value="0x0011" /></sequence>
    </sequence>
  </attribute>
  <attribute id="0x0005">
    <sequence><uuid value="0x1002" /></sequence>
  </attribute>
  <attribute id="0x0006">
    <sequence>
      <uint16 value="0x656e" />
      <uint16 value="0x006a" />
      <uint16 value="0x0100" />
    </sequence>
  </attribute>
  <attribute id="0x0009">
    <sequence>
      <sequence>
        <uuid value="0x1124" />
        <uint16 value="0x0100" />
      </sequence>
    </sequence>
  </attribute>
  <attribute id="0x000d">
    <sequence>
      <sequence>
        <sequence>
          <uuid value="0x0100" />
          <uint16 value="0x0013" />
        </sequence>
        <sequence><uuid value="0x0011" /></sequence>
      </sequence>
    </sequence>
  </attribute>
  <attribute id="0x0100"><text value="{name}" /></attribute>
  <attribute id="0x0101"><text value="Virtuelt Bluetooth-tastatur og mus" /></attribute>
  <attribute id="0x0102"><text value="btkbd" /></attribute>
  <attribute id="0x0200"><uint16 value="0x0100" /></attribute>
  <attribute id="0x0201"><uint16 value="0x0111" /></attribute>
  <attribute id="0x0202"><uint8 value="0xc0" /></attribute>
  <attribute id="0x0203"><uint8 value="0x00" /></attribute>
  <attribute id="0x0204"><boolean value="true" /></attribute>
  <attribute id="0x0205"><boolean value="true" /></attribute>
  <attribute id="0x0206">
    <sequence>
      <sequence>
        <uint8 value="0x22" />
        <text encoding="hex" value="{desc_hex}" />
      </sequence>
    </sequence>
  </attribute>
  <attribute id="0x0207">
    <sequence>
      <sequence>
        <uint16 value="0x0409" />
        <uint16 value="0x0100" />
      </sequence>
    </sequence>
  </attribute>
  <attribute id="0x020b"><uint16 value="0x0100" /></attribute>
  <attribute id="0x020c"><uint16 value="0x0c80" /></attribute>
  <attribute id="0x020d"><boolean value="true" /></attribute>
  <attribute id="0x020e"><boolean value="false" /></attribute>
</record>
"""


# --------------------------------------------------------------------------
# evdev -> HID usage
# --------------------------------------------------------------------------

def build_keymap():
    from evdev import ecodes as e

    letters = {getattr(e, f"KEY_{c}"): 0x04 + i
               for i, c in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZ")}
    digits = {e.KEY_1: 0x1E, e.KEY_2: 0x1F, e.KEY_3: 0x20, e.KEY_4: 0x21,
              e.KEY_5: 0x22, e.KEY_6: 0x23, e.KEY_7: 0x24, e.KEY_8: 0x25,
              e.KEY_9: 0x26, e.KEY_0: 0x27}
    fkeys = {getattr(e, f"KEY_F{n}"): 0x3A + n - 1 for n in range(1, 13)}
    fkeys.update({getattr(e, f"KEY_F{n}"): 0x68 + n - 13 for n in range(13, 25)})
    kp = {e.KEY_KP1: 0x59, e.KEY_KP2: 0x5A, e.KEY_KP3: 0x5B, e.KEY_KP4: 0x5C,
          e.KEY_KP5: 0x5D, e.KEY_KP6: 0x5E, e.KEY_KP7: 0x5F, e.KEY_KP8: 0x60,
          e.KEY_KP9: 0x61, e.KEY_KP0: 0x62, e.KEY_KPDOT: 0x63}

    m = {}
    m.update(letters)
    m.update(digits)
    m.update(fkeys)
    m.update(kp)
    m.update({
        e.KEY_ENTER: 0x28, e.KEY_ESC: 0x29, e.KEY_BACKSPACE: 0x2A,
        e.KEY_TAB: 0x2B, e.KEY_SPACE: 0x2C, e.KEY_MINUS: 0x2D,
        e.KEY_EQUAL: 0x2E, e.KEY_LEFTBRACE: 0x2F, e.KEY_RIGHTBRACE: 0x30,
        e.KEY_BACKSLASH: 0x31, e.KEY_SEMICOLON: 0x33, e.KEY_APOSTROPHE: 0x34,
        e.KEY_GRAVE: 0x35, e.KEY_COMMA: 0x36, e.KEY_DOT: 0x37, e.KEY_SLASH: 0x38,
        e.KEY_CAPSLOCK: 0x39,
        e.KEY_SYSRQ: 0x46, e.KEY_SCROLLLOCK: 0x47, e.KEY_PAUSE: 0x48,
        e.KEY_INSERT: 0x49, e.KEY_HOME: 0x4A, e.KEY_PAGEUP: 0x4B,
        e.KEY_DELETE: 0x4C, e.KEY_END: 0x4D, e.KEY_PAGEDOWN: 0x4E,
        e.KEY_RIGHT: 0x4F, e.KEY_LEFT: 0x50, e.KEY_DOWN: 0x51, e.KEY_UP: 0x52,
        e.KEY_NUMLOCK: 0x53, e.KEY_KPSLASH: 0x54, e.KEY_KPASTERISK: 0x55,
        e.KEY_KPMINUS: 0x56, e.KEY_KPPLUS: 0x57, e.KEY_KPENTER: 0x58,
        # 0x64 er "<>|"-tasten ved siden av venstre shift. Uten denne
        # mangler du < > og | på nordisk layout.
        e.KEY_102ND: 0x64,
        e.KEY_COMPOSE: 0x65,
        e.KEY_MUTE: 0x7F, e.KEY_VOLUMEUP: 0x80, e.KEY_VOLUMEDOWN: 0x81,
    })
    return m


def parse_chord(spec: str) -> set[int]:
    """'KEY_LEFTSHIFT+KEY_RIGHTSHIFT' -> {42, 54}"""
    from evdev import ecodes as e

    codes = set()
    for part in spec.split("+"):
        part = part.strip().upper()
        if not part.startswith("KEY_"):
            part = "KEY_" + part
        code = getattr(e, part, None)
        if code is None:
            sys.exit(f"Ukjent tast: {part}. Bruk evdev-navn, f.eks. KEY_LEFTALT.")
        codes.add(code)
    if not codes:
        sys.exit("Tom vekselkombinasjon.")
    return codes


def build_modmap():
    from evdev import ecodes as e
    return {
        e.KEY_LEFTCTRL: 0x01, e.KEY_LEFTSHIFT: 0x02,
        e.KEY_LEFTALT: 0x04, e.KEY_LEFTMETA: 0x08,
        e.KEY_RIGHTCTRL: 0x10, e.KEY_RIGHTSHIFT: 0x20,
        e.KEY_RIGHTALT: 0x40, e.KEY_RIGHTMETA: 0x80,
    }


# --------------------------------------------------------------------------
# Konsoll: én delt stdin-leser for parringsagenten og REPL-en
# --------------------------------------------------------------------------

class Console:
    """Trådsikker stdin-leser. Agenten (kjører på BlueZ' D-Bus-tråd) og
    REPL-en (kjører på asyncio-tråden) kan begge trenge å lese en linje fra
    brukeren - uten denne ville de kunne stjele hverandres inntastinger.
    En egen pumpe-tråd fyller en kø; ask() tar neste linje og serialiserer
    kallene med en lås, så bare én "spørsmål pågår" til enhver tid.
    """

    def __init__(self):
        self.interactive = sys.stdin.isatty()
        self._lines: queue.Queue = queue.Queue()
        self._lock = threading.Lock()
        self._closed = not self.interactive
        if self.interactive:
            threading.Thread(target=self._pump, daemon=True).start()

    def _pump(self):
        for line in sys.stdin:
            self._lines.put(line.rstrip("\n"))
        self._lines.put(None)  # EOF - stdin stengt

    def ask(self, prompt: str) -> str | None:
        """Skriver prompt og blokkerer til en linje kommer. None ved EOF
        eller hvis det aldri fantes et terminal-vindu å spørre i."""
        if self._closed:
            return None
        with self._lock:
            print(prompt, end="", flush=True)
            line = self._lines.get()
            if line is None:
                self._closed = True
                return None
            return line


# --------------------------------------------------------------------------
# BlueZ D-Bus
# --------------------------------------------------------------------------

class Bluez:
    """Registrerer HID-profilen og setter adapteren i riktig modus."""

    def __init__(self, adapter: str, name: str):
        try:
            import dbus
            import dbus.service
            from dbus.mainloop.glib import DBusGMainLoop
            from gi.repository import GLib
        except ImportError as exc:
            sys.exit(f"Mangler avhengighet ({exc}). "
                     "Installer: sudo pacman -S python-dbus python-gobject python-evdev")

        self.dbus = dbus
        DBusGMainLoop(set_as_default=True)
        self.bus = dbus.SystemBus()
        self.adapter_path = f"/org/bluez/{adapter}"
        self.name = name

        try:
            self.adapter_props = dbus.Interface(
                self.bus.get_object("org.bluez", self.adapter_path),
                "org.freedesktop.DBus.Properties")
        except dbus.DBusException:
            sys.exit(f"Fant ikke adapteren {adapter}. Er Bluetooth slått på?")

        class Profile(dbus.service.Object):
            @dbus.service.method("org.bluez.Profile1")
            def Release(self):
                pass

            @dbus.service.method("org.bluez.Profile1", in_signature="oha{sv}")
            def NewConnection(self, path, fd, props):
                # Vi håndterer L2CAP selv; lukk fd-en BlueZ måtte sende.
                try:
                    os.close(fd)
                except OSError:
                    pass

            @dbus.service.method("org.bluez.Profile1", in_signature="o")
            def RequestDisconnection(self, path):
                pass

        self._profile = Profile(self.bus, PROFILE_PATH)
        self._loop = GLib.MainLoop()
        threading.Thread(target=self._loop.run, daemon=True).start()

    def _set(self, prop, value):
        self.adapter_props.Set("org.bluez.Adapter1", prop, value)

    def prepare_adapter(self, discoverable: bool):
        d = self.dbus
        self._set("Powered", d.Boolean(True))
        self._set("Alias", d.String(self.name))
        self._set("Pairable", d.Boolean(True))
        if discoverable:
            self._set("DiscoverableTimeout", d.UInt32(0))
            self._set("Discoverable", d.Boolean(True))

    def register_profile(self):
        d = self.dbus
        manager = d.Interface(self.bus.get_object("org.bluez", "/org/bluez"),
                              "org.bluez.ProfileManager1")
        opts = {
            "ServiceRecord": sdp_record(self.name),
            "Role": "server",
            "RequireAuthentication": d.Boolean(True),
            "RequireAuthorization": d.Boolean(False),
            "AutoConnect": d.Boolean(True),
        }
        try:
            manager.UnregisterProfile(PROFILE_PATH)
        except Exception:
            pass
        try:
            manager.RegisterProfile(PROFILE_PATH, HID_UUID, opts)
        except d.DBusException as exc:
            if "already registered" in str(exc).lower():
                sys.exit(
                    "BlueZ nekter å registrere HID-profilen fordi UUID-en "
                    "allerede er tatt.\n" + PLUGIN_HELP +
                    "\nEr pluginet allerede av, kjører det trolig en annen "
                    "btkbd-prosess: pgrep -af btkbd")
            raise

    def register_agent(self, console: Console):
        """Registrerer en pairing-agent i denne prosessen, slik at
        parringskoden fra verten skrives rett i dette terminalvinduet
        i stedet for i et eget `bluetoothctl`-vindu.

        KeyboardOnly er samme evne som README tidligere ba deg sette manuelt
        med `agent KeyboardOnly` i bluetoothctl - det er nettopp den evnen
        som gjør at BlueZ velger passkey-metoden Windows viser koden for.
        """
        d = self.dbus

        class Agent(d.service.Object):
            def __init__(self, bus):
                super().__init__(bus, AGENT_PATH)

            @d.service.method("org.bluez.Agent1", in_signature="", out_signature="")
            def Release(self):
                pass

            @d.service.method("org.bluez.Agent1", in_signature="o", out_signature="")
            def RequestAuthorization(self, device):
                pass  # egen HID-profil, ikke tredjeparts - godta stille

            @d.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
            def AuthorizeService(self, device, uuid):
                pass

            @d.service.method("org.bluez.Agent1", in_signature="o", out_signature="s")
            def RequestPinCode(self, device):
                svar = console.ask("[btkbd] Skriv PIN-kode fra verten: ")
                if svar is None:
                    raise d.exceptions.DBusException(
                        "ingen terminal å spørre i", name="org.bluez.Error.Canceled")
                return svar

            @d.service.method("org.bluez.Agent1", in_signature="ou", out_signature="")
            def DisplayPinCode(self, device, pincode):
                log(f"PIN-kode fra verten: {pincode}")

            @d.service.method("org.bluez.Agent1", in_signature="o", out_signature="u")
            def RequestPasskey(self, device):
                while True:
                    svar = console.ask("[btkbd] Skriv koden verten viser: ")
                    if svar is None:
                        raise d.exceptions.DBusException(
                            "ingen terminal å spørre i", name="org.bluez.Error.Canceled")
                    try:
                        return d.UInt32(int(svar))
                    except ValueError:
                        print("Må være tall.")

            @d.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
            def DisplayPasskey(self, device, passkey, entered):
                log(f"passkey {passkey:06d} ({entered} tegn skrevet av verten)")

            @d.service.method("org.bluez.Agent1", in_signature="ou", out_signature="")
            def RequestConfirmation(self, device, passkey):
                svar = console.ask(f"[btkbd] Bekreft kode {passkey:06d} - stemmer "
                                   "det med det verten viser? [j/N] ")
                if svar is None or svar.strip().lower() not in ("j", "ja", "y", "yes"):
                    raise d.exceptions.DBusException(
                        "avvist", name="org.bluez.Error.Rejected")

            @d.service.method("org.bluez.Agent1", in_signature="", out_signature="")
            def Cancel(self):
                log("parring avbrutt av verten")

        self._agent = Agent(self.bus)
        manager = d.Interface(
            self.bus.get_object("org.bluez", "/org/bluez"),
            "org.bluez.AgentManager1")
        manager.RegisterAgent(AGENT_PATH, "KeyboardOnly")
        manager.RequestDefaultAgent(AGENT_PATH)

    def paired_devices(self) -> list[dict]:
        """Enheter BlueZ allerede har parret, nyeste-ish først fra BlueZ'
        egen rekkefølge. Brukes til enhetsvelgeren og REPL-ens `list`."""
        manager = self.dbus.Interface(
            self.bus.get_object("org.bluez", "/"),
            "org.freedesktop.DBus.ObjectManager")
        result = []
        for _path, ifaces in manager.GetManagedObjects().items():
            dev = ifaces.get("org.bluez.Device1")
            if dev and bool(dev.get("Paired")):
                result.append({
                    "address": str(dev.get("Address", "")),
                    "name": str(dev.get("Alias") or dev.get("Name") or "?"),
                    "connected": bool(dev.get("Connected", False)),
                })
        return result


# --------------------------------------------------------------------------
# L2CAP-transport
# --------------------------------------------------------------------------

class HidTransport:
    """Eier control- og interrupt-kanalene mot HID-verten."""

    def __init__(self, on_state_change=None):
        self.ctrl = None
        self.intr = None
        self.peer = None
        self.on_state_change = on_state_change
        self._srv_ctrl = None
        self._srv_intr = None
        self._lock = asyncio.Lock()
        self._disconnect_event = asyncio.Event()

    @property
    def connected(self) -> bool:
        return self.intr is not None

    async def wait_disconnected(self):
        """Venter til forbindelsen faller (brukes av reconnect_loop for å
        reagere umiddelbart i stedet for å polle)."""
        await self._disconnect_event.wait()
        self._disconnect_event.clear()

    async def disconnect(self):
        """Kobler fra nåværende vert på brukerens forespørsel (REPL)."""
        if self.ctrl or self.intr:
            await self._detach()

    # -- server-side --------------------------------------------------------

    def listen(self):
        self._srv_ctrl = self._listen_psm(PSM_CTRL)
        self._srv_intr = self._listen_psm(PSM_INTR)

    @staticmethod
    def _listen_psm(psm: int):
        s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET,
                          socket.BTPROTO_L2CAP)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind((BDADDR_ANY, psm))
        except OSError as exc:
            if exc.errno == errno.EADDRINUSE:
                sys.exit(
                    f"PSM {psm} er opptatt. Det betyr nesten alltid at "
                    "input-pluginet i bluetoothd fortsatt kjører.\n"
                    "Kjør ./setup-bluez.sh, eller legg til '-P input' i "
                    "ExecStart for bluetooth.service.")
            if exc.errno == errno.EACCES:
                sys.exit("Nektet tilgang til lav L2CAP-PSM. Kjør som root.")
            raise
        s.listen(1)
        s.setblocking(False)
        return s

    async def accept_loop(self):
        loop = asyncio.get_running_loop()
        while True:
            ctrl, addr = await loop.sock_accept(self._srv_ctrl)
            log(f"control-kanal fra {addr[0]}")
            try:
                intr, _ = await asyncio.wait_for(
                    loop.sock_accept(self._srv_intr), timeout=10)
            except asyncio.TimeoutError:
                log("verten åpnet aldri interrupt-kanalen, avbryter")
                ctrl.close()
                continue
            ctrl.setblocking(False)
            intr.setblocking(False)
            await self._attach(ctrl, intr, addr[0])
            await self._serve_ctrl()

    # -- client-side (vi kobler ut mot en paret vert) ------------------------

    async def connect_to(self, mac: str) -> bool:
        if self.ctrl or self.intr:
            # Allerede tilkoblet (f.eks. REPL ber om en ny mens en gammel
            # henger igjen) - rydd opp gamle sockets først, ellers lekker de.
            await self._detach()
        loop = asyncio.get_running_loop()
        socks = []
        try:
            for psm in (PSM_CTRL, PSM_INTR):
                s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET,
                                  socket.BTPROTO_L2CAP)
                s.setblocking(False)
                await asyncio.wait_for(loop.sock_connect(s, (mac, psm)),
                                       timeout=10)
                socks.append(s)
        except (OSError, asyncio.TimeoutError) as exc:
            for s in socks:
                s.close()
            log(f"klarte ikke koble til {mac}: {exc}")
            return False
        await self._attach(socks[0], socks[1], mac)
        asyncio.create_task(self._serve_ctrl())
        return True

    # -- felles -------------------------------------------------------------

    async def _attach(self, ctrl, intr, peer):
        self.ctrl, self.intr, self.peer = ctrl, intr, peer
        log(f"HID-forbindelse oppe mot {peer}")
        if self.on_state_change:
            self.on_state_change(True)

    async def _detach(self):
        for s in (self.ctrl, self.intr):
            if s:
                s.close()
        self.ctrl = self.intr = None
        peer, self.peer = self.peer, None
        log(f"forbindelsen mot {peer} falt")
        self._disconnect_event.set()
        if self.on_state_change:
            self.on_state_change(False)

    async def send(self, report_id: int, payload: bytes):
        if not self.intr:
            return
        packet = bytes([HIDP_DATA | RTYPE_INPUT, report_id]) + payload
        try:
            await asyncio.get_running_loop().sock_sendall(self.intr, packet)
        except OSError:
            await self._detach()

    async def _serve_ctrl(self):
        """Svarer på forespørsler fra verten så den ikke kobler ned."""
        loop = asyncio.get_running_loop()
        while self.ctrl:
            try:
                data = await loop.sock_recv(self.ctrl, 128)
            except OSError:
                data = b""
            if not data:
                await self._detach()
                return
            msg_type = data[0] & 0xF0
            try:
                if msg_type == HIDP_GET_REPORT:
                    await loop.sock_sendall(
                        self.ctrl,
                        bytes([HIDP_DATA | RTYPE_INPUT, KEYBOARD_REPORT_ID])
                        + bytes(8))
                elif msg_type in (HIDP_SET_REPORT, HIDP_SET_PROTOCOL):
                    await loop.sock_sendall(
                        self.ctrl, bytes([HIDP_HANDSHAKE | HS_SUCCESSFUL]))
                elif msg_type == HIDP_GET_PROTOCOL:
                    await loop.sock_sendall(self.ctrl, bytes([HIDP_DATA, 0x01]))
                elif msg_type == HIDP_HID_CONTROL:
                    # 0x15 = VIRTUAL_CABLE_UNPLUG
                    if len(data) and (data[0] & 0x0F) == 0x05:
                        await self._detach()
                        return
                else:
                    await loop.sock_sendall(
                        self.ctrl, bytes([HIDP_HANDSHAKE | HS_ERR_UNSUPPORTED]))
            except OSError:
                await self._detach()
                return


# --------------------------------------------------------------------------
# Tilstand for tastatur og mus
# --------------------------------------------------------------------------

class KeyboardState:
    def __init__(self):
        self.mods = 0
        self.keys: list[int] = []

    def press(self, usage: int) -> bool:
        if usage in self.keys:
            return False
        if len(self.keys) >= 6:
            self.keys.pop(0)
        self.keys.append(usage)
        return True

    def release(self, usage: int) -> bool:
        if usage in self.keys:
            self.keys.remove(usage)
            return True
        return False

    def clear(self):
        self.mods = 0
        self.keys.clear()

    def report(self) -> bytes:
        keys = self.keys + [0] * (6 - len(self.keys))
        return bytes([self.mods, 0]) + bytes(keys[:6])


class MouseState:
    def __init__(self):
        self.buttons = 0
        self.dx = 0.0
        self.dy = 0.0
        self.wheel = 0
        self.hwheel = 0
        self.dirty = False

    def clear(self):
        self.buttons = 0
        self.dx = self.dy = 0.0
        self.wheel = self.hwheel = 0

    def take_report(self) -> bytes | None:
        dx = int(self.dx)
        dy = int(self.dy)
        self.dx -= dx
        self.dy -= dy
        wheel, hwheel = self.wheel, self.hwheel
        self.wheel = self.hwheel = 0
        if not (dx or dy or wheel or hwheel) and not self.dirty:
            return None
        self.dirty = False
        clamp = lambda v, lo, hi: max(lo, min(hi, v))
        return struct.pack("<Bhhbb", self.buttons,
                           clamp(dx, -32767, 32767), clamp(dy, -32767, 32767),
                           clamp(wheel, -127, 127), clamp(hwheel, -127, 127))


# --------------------------------------------------------------------------
# Touchpad: absolutte multitouch-events -> relative musebevegelser
# --------------------------------------------------------------------------

class TouchpadTracker:
    def __init__(self, device, speed: float, scroll_speed: float,
                 tap_enabled: bool, natural_scroll: bool):
        from evdev import ecodes as e
        self.e = e
        self.speed = speed
        self.scroll_speed = scroll_speed
        self.tap_enabled = tap_enabled
        self.scroll_sign = -1 if natural_scroll else 1

        caps = device.capabilities(absinfo=True).get(e.EV_ABS, [])
        self.res_x = 1
        self.res_y = 1
        for code, info in caps:
            if code == e.ABS_X and info.resolution:
                self.res_x = info.resolution
            if code == e.ABS_Y and info.resolution:
                self.res_y = info.resolution
        # Fallback for pads uten oppgitt oppløsning
        self.res_x = self.res_x or 30
        self.res_y = self.res_y or 30

        self.slot = 0
        self.pos = {}          # slot -> [x, y]
        self.active = set()
        self.prev = None       # forrige posisjon for aktiv gest
        self.fingers = 0
        self.touch_start = 0.0
        self.moved = 0.0
        self.scroll_acc = [0.0, 0.0]
        self.pending_tap = False

    def handle(self, ev, mouse: MouseState) -> list[tuple[int, bool]]:
        """Returnerer liste av (knappebit, trykket) for tap-klikk."""
        e = self.e
        clicks = []

        if ev.type == e.EV_ABS:
            if ev.code == e.ABS_MT_SLOT:
                self.slot = ev.value
            elif ev.code == e.ABS_MT_TRACKING_ID:
                if ev.value == -1:
                    self.active.discard(self.slot)
                    self.pos.pop(self.slot, None)
                else:
                    self.active.add(self.slot)
            elif ev.code == e.ABS_MT_POSITION_X:
                self.pos.setdefault(self.slot, [0, 0])[0] = ev.value
            elif ev.code == e.ABS_MT_POSITION_Y:
                self.pos.setdefault(self.slot, [0, 0])[1] = ev.value

        elif ev.type == e.EV_KEY and ev.code == e.BTN_TOUCH:
            if ev.value == 1:
                self.touch_start = time.monotonic()
                self.moved = 0.0
                self.pending_tap = self.tap_enabled
            else:
                if (self.pending_tap
                        and time.monotonic() - self.touch_start < 0.18
                        and self.moved < 4.0):
                    clicks.append((0x01, True))
                    clicks.append((0x01, False))
                self.pending_tap = False
                self.prev = None

        elif ev.type == e.EV_SYN and ev.code == e.SYN_REPORT:
            n = len(self.active)
            if n != self.fingers:
                self.fingers = n
                self.prev = None
                self.scroll_acc = [0.0, 0.0]
                if n > 1:
                    self.pending_tap = False

            if n in (1, 2) and self.active:
                first = min(self.active)
                cur = self.pos.get(first)
                if cur is None:
                    return clicks
                if self.prev is not None:
                    dx_mm = (cur[0] - self.prev[0]) / self.res_x
                    dy_mm = (cur[1] - self.prev[1]) / self.res_y
                    self.moved += abs(dx_mm) + abs(dy_mm)
                    if n == 1:
                        mouse.dx += dx_mm * self.speed
                        mouse.dy += dy_mm * self.speed
                    else:
                        self.scroll_acc[0] += dx_mm * self.scroll_speed
                        self.scroll_acc[1] += dy_mm * self.scroll_speed
                        for axis in (0, 1):
                            ticks = int(self.scroll_acc[axis])
                            if ticks:
                                self.scroll_acc[axis] -= ticks
                                if axis == 1:
                                    mouse.wheel -= ticks * self.scroll_sign
                                else:
                                    mouse.hwheel += ticks * self.scroll_sign
                self.prev = list(cur)
            else:
                self.prev = None

        return clicks


# --------------------------------------------------------------------------
# Ruteren: leser evdev, bytter modus, sender rapporter
# --------------------------------------------------------------------------

DROPIN = "/etc/systemd/system/bluetooth.service.d/btkbd.conf"
MAIN_CONF = "/etc/bluetooth/main.conf"
COD_KEYBOARD = "0x0025C0"


def find_bluetoothd_binary() -> str:
    import shutil
    path = shutil.which("bluetoothd")
    if path:
        return path
    for cand in ("/usr/lib/bluetooth/bluetoothd",
                 "/usr/libexec/bluetooth/bluetoothd",
                 "/usr/sbin/bluetoothd"):
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    sys.exit("Fant ikke bluetoothd. Er bluez installert?")


def patch_main_conf(undo: bool) -> bool:
    """Setter eller fjerner Class i main.conf. Returnerer True ved endring."""
    import re
    if not os.path.isfile(MAIN_CONF):
        return False
    with open(MAIN_CONF) as fh:
        text = fh.read()
    original = text

    if undo:
        text = re.sub(r"(?m)^Class\s*=\s*" + COD_KEYBOARD + r"\s*\n", "", text)
    elif re.search(r"(?m)^\s*#?\s*Class\s*=", text):
        text = re.sub(r"(?m)^\s*#?\s*Class\s*=.*$", f"Class = {COD_KEYBOARD}",
                      text, count=1)
    elif re.search(r"(?m)^\[General\]", text):
        text = re.sub(r"(?m)^\[General\]",
                      f"[General]\nClass = {COD_KEYBOARD}", text, count=1)
    else:
        text += f"\n[General]\nClass = {COD_KEYBOARD}\n"

    if text == original:
        return False
    if not undo and not os.path.exists(MAIN_CONF + ".btkbd-backup"):
        with open(MAIN_CONF + ".btkbd-backup", "w") as fh:
            fh.write(original)
    with open(MAIN_CONF, "w") as fh:
        fh.write(text)
    return True


def run_setup(undo: bool, assume_yes: bool, standalone: bool = True):
    import shutil
    import subprocess

    if os.geteuid() != 0:
        sys.exit("--setup må kjøres som root.")
    if not shutil.which("systemctl"):
        sys.exit("Fant ikke systemctl. Konfigurer bluetoothd manuelt, "
                 "se README.")

    if undo:
        print(f"Dette fjerner {DROPIN}, fjerner Class fra {MAIN_CONF},\n"
              "og starter bluetooth.service på nytt.")
    else:
        binary = find_bluetoothd_binary()
        print("Dette endrer systemkonfigurasjonen:\n")
        print(f"  {DROPIN}")
        print(f"      ExecStart={binary} -P input")
        print(f"  {MAIN_CONF}")
        print(f"      Class = {COD_KEYBOARD}")
        print("\n  systemctl daemon-reload && systemctl restart bluetooth\n")
        print("Konsekvenser:")
        print("  - omstarten kobler ned alt som er tilkoblet nå,")
        print("    inkludert Bluetooth-hodetelefoner")
        print("  - så lenge dette står, kan ikke maskinen bruke")
        print("    Bluetooth-tastatur eller -mus selv (lyd er upåvirket)")
        print("  - reverseres med: sudo ./btkbd.py --setup --undo")

    if not assume_yes:
        try:
            svar = input("\nFortsette? [j/N] ").strip().lower()
        except EOFError:
            svar = ""
        if svar not in ("j", "ja", "y", "yes"):
            sys.exit("Avbrutt.")

    if undo:
        if os.path.exists(DROPIN):
            os.remove(DROPIN)
        try:
            os.rmdir(os.path.dirname(DROPIN))
        except OSError:
            pass
    else:
        os.makedirs(os.path.dirname(DROPIN), exist_ok=True)
        with open(DROPIN, "w") as fh:
            fh.write(f"[Service]\nExecStart=\n"
                     f"ExecStart={find_bluetoothd_binary()} -P input\n")
    patch_main_conf(undo)

    subprocess.run(["systemctl", "daemon-reload"], check=True)
    subprocess.run(["systemctl", "restart", "bluetooth"], check=True)

    # Vent til bluetoothd er oppe igjen, og bekreft at det tok
    for _ in range(30):
        time.sleep(0.2)
        pid, argv = find_bluetoothd()
        if pid:
            break
    else:
        sys.exit("bluetoothd kom ikke opp igjen. Sjekk: systemctl status bluetooth")

    if undo:
        print("\nTilbakestilt. Bluetooth-tastatur og -mus virker normalt igjen.")
    elif input_plugin_disabled(argv):
        print(f"\nFerdig. bluetoothd (pid {pid}) kjører nå uten input-pluginet.")
        if standalone:
            print("Start btkbd som vanlig: sudo ./btkbd.py")
    else:
        sys.exit(f"Konfigurasjonen ble skrevet, men bluetoothd kjører "
                 f"fortsatt som:\n  {' '.join(argv)}\n"
                 "Sjekk om noe annet overstyrer unit-fila: "
                 "systemctl cat bluetooth")


def find_bluetoothd():
    """Returnerer (pid, argv) for kjørende bluetoothd, eller (None, None)."""
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/comm") as fh:
                if fh.read().strip() != "bluetoothd":
                    continue
            with open(f"/proc/{entry}/cmdline", "rb") as fh:
                argv = [a.decode() for a in fh.read().split(b"\0") if a]
            return int(entry), argv
        except OSError:
            continue
    return None, None


def input_plugin_disabled(argv) -> bool:
    """Sant hvis bluetoothd ble startet uten input-pluginet."""
    def values(flag_short, flag_long):
        out = []
        it = iter(argv[1:])
        for a in it:
            if a in (flag_short, flag_long):
                out.append(next(it, ""))
            elif a.startswith(flag_long + "="):
                out.append(a.split("=", 1)[1])
            elif a.startswith(flag_short) and len(a) > len(flag_short):
                out.append(a[len(flag_short):])
        return [p.strip() for v in out for p in v.split(",") if p.strip()]

    if "input" in values("-P", "--noplugin"):
        return True
    only = values("-p", "--plugin")
    return bool(only) and "input" not in only


def print_status():
    pid, argv = find_bluetoothd()
    if pid is None:
        print("bluetoothd kjører ikke.")
        return
    if input_plugin_disabled(argv):
        print(f"enhet - bluetoothd (pid {pid}) kjører uten input-pluginet.\n"
              "        Klar for btkbd, men laptopen kan ikke selv bruke "
              "Bluetooth-tastatur/-mus.")
    else:
        print(f"vert  - bluetoothd (pid {pid}) kjører med input-pluginet aktivt.\n"
              "        Vanlig modus - laptopen kan bruke egne "
              "Bluetooth-tastatur/-mus.\n"
              "        `btkbd` bytter til enhet-modus automatisk (med "
              "bekreftelse) når du starter den.")


PLUGIN_HELP = """
input-pluginet i bluetoothd er fortsatt aktivt. Det eier HID-UUID-en
(0x1124) og L2CAP-portene 17 og 19, fordi den normalt *tar imot*
tastaturer. Du kan ikke være HID-vert og HID-enhet samtidig.

Fiks:
    sudo ./btkbd.py --setup

Eller manuelt:
    sudo systemctl edit bluetooth.service
        [Service]
        ExecStart=
        ExecStart=/usr/lib/bluetooth/bluetoothd -P input
    sudo systemctl restart bluetooth

Verifiser med:
    systemctl cat bluetooth | grep ExecStart
    pgrep -a bluetoothd
"""


def preflight(cfg):
    pid, argv = find_bluetoothd()
    if pid is None:
        sys.exit("bluetoothd kjører ikke. Start den: sudo systemctl start bluetooth")

    if not input_plugin_disabled(argv):
        log(f"bluetoothd (pid {pid}): {' '.join(argv)}")
        log("input-pluginet er aktivt - kan ikke være HID-vert og -enhet "
            "samtidig. Kjører oppsettet (sudo ./btkbd.py --setup) nå:")
        run_setup(undo=False, assume_yes=cfg.yes, standalone=False)

    # Definitiv test: klarer vi å legge beslag på HID-portene?
    for psm in (PSM_CTRL, PSM_INTR):
        s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET,
                          socket.BTPROTO_L2CAP)
        try:
            s.bind((BDADDR_ANY, psm))
        except OSError as exc:
            s.close()
            if exc.errno == errno.EADDRINUSE:
                sys.exit(f"L2CAP PSM {psm} er opptatt av en annen prosess.\n"
                         "Kjører det allerede en btkbd? Sjekk: pgrep -af btkbd")
            if exc.errno == errno.EACCES:
                sys.exit("Nektet tilgang til lave L2CAP-porter. Kjør som root.")
            raise
        s.close()


def log(msg: str):
    print(f"[btkbd] {msg}", flush=True)


class Router:
    def __init__(self, transport: HidTransport, devices, cfg):
        from evdev import ecodes as e
        self.e = e
        self.t = transport
        self.cfg = cfg
        self.devices = devices
        self.keymap = build_keymap()
        self.modmap = build_modmap()
        self.kb = KeyboardState()
        self.mouse = MouseState()
        self.debug = getattr(cfg, "debug", False)
        self.remote = False
        self.grabbed = set()
        self.down = set()          # alle taster som er fysisk nede
        self.chord = parse_chord(cfg.toggle)
        self._hold_task = None
        self._armed = False
        self.trackers = {}

        if not self.chord <= set(self.modmap):
            log("advarsel: vekselkombinasjonen inneholder taster som ikke er "
                "rene modifiers - de vil også nå programmet du sitter i.")

        self.btnmap = {
            e.BTN_LEFT: 0x01, e.BTN_RIGHT: 0x02, e.BTN_MIDDLE: 0x04,
            e.BTN_SIDE: 0x08, e.BTN_EXTRA: 0x10,
        }

        for dev in devices:
            if dev.kind == "touchpad":
                self.trackers[dev.dev.path] = TouchpadTracker(
                    dev.dev, cfg.touchpad_speed, cfg.scroll_speed,
                    not cfg.no_tap, cfg.natural_scroll)

    # -- modus --------------------------------------------------------------

    def on_link_change(self, up: bool):
        if not up and self.remote:
            log("mistet forbindelsen - slipper tastaturet")
            asyncio.create_task(self.set_remote(False))

    async def set_remote(self, on: bool):
        if on == self.remote:
            return
        if on and not self.t.connected:
            log("ingen HID-forbindelse - blir værende lokalt")
            return
        if on:
            if self.down:
                log("venter til alle taster er sluppet ...")
                return
            for d in self.devices:
                try:
                    d.dev.grab()
                    self.grabbed.add(d.dev.path)
                except OSError as exc:
                    log(f"kunne ikke ta {d.dev.path}: {exc}")
            self.kb.clear()
            self.mouse.clear()
            await self.t.send(KEYBOARD_REPORT_ID, self.kb.report())
            self.remote = True
            log("\033[1;32mREMOTE\033[0m - alt går til gamingpcen "
                f"(hold {self.cfg.toggle} igjen for å komme tilbake)")
        else:
            self.kb.clear()
            self.mouse.clear()
            await self.t.send(KEYBOARD_REPORT_ID, self.kb.report())
            await self.t.send(MOUSE_REPORT_ID, struct.pack("<Bhhbb", 0, 0, 0, 0, 0))
            for d in self.devices:
                if d.dev.path in self.grabbed:
                    try:
                        d.dev.ungrab()
                    except OSError:
                        pass
            self.grabbed.clear()
            self.remote = False
            log("\033[1;34mLOKAL\033[0m - tastaturet er ditt igjen")

    async def _hold_watch(self):
        """Armerer byttet når kombinasjonen har vært holdt lenge nok."""
        try:
            await asyncio.sleep(self.cfg.toggle_hold)
            self._armed = True
            target = "LOKAL" if self.remote else "REMOTE"
            log(f"\033[1;33mklar\033[0m - slipp tastene for å gå til {target}")
        except asyncio.CancelledError:
            pass
        finally:
            self._hold_task = None

    async def _chord_update(self):
        """Byttet skjer først når kombinasjonen slippes.

        Da rekker kompositoren å se både trykk og slipp, og sitter aldri
        igjen med en modifier som henger.
        """
        if self.chord <= self.down:
            if self._hold_task is None and not self._armed:
                self._hold_task = asyncio.create_task(self._hold_watch())
            return

        if self._hold_task:
            self._hold_task.cancel()
            self._hold_task = None

        if self._armed and not (self.chord & self.down):
            self._armed = False
            if self.down:
                log("avbrutt - andre taster var fortsatt nede")
            else:
                await self.set_remote(not self.remote)

    # -- hovedløkke per enhet ----------------------------------------------

    async def run(self):
        tasks = [asyncio.create_task(self._read(d)) for d in self.devices]
        tasks.append(asyncio.create_task(self._mouse_sender()))
        await asyncio.gather(*tasks)

    async def _mouse_sender(self):
        interval = 1.0 / self.cfg.mouse_rate
        last_log = 0.0
        while True:
            await asyncio.sleep(interval)
            if self.remote and self.t.connected:
                rep = self.mouse.take_report()
                if rep:
                    await self.t.send(MOUSE_REPORT_ID, rep)
                    if self.debug:
                        now = time.monotonic()
                        if now - last_log > 0.1:
                            last_log = now
                            btn, dx, dy, wh, hp = struct.unpack("<Bhhbb", rep)
                            log(f"mus -> knapper={btn:#04x} dx={dx} dy={dy} "
                                f"hjul={wh}")

    async def _read(self, d):
        e = self.e
        async for ev in d.dev.async_read_loop():
            if ev.type == e.EV_KEY:
                await self._on_key(ev)
            elif ev.type == e.EV_REL and self.remote:
                if ev.code == e.REL_X:
                    self.mouse.dx += ev.value * self.cfg.mouse_speed
                elif ev.code == e.REL_Y:
                    self.mouse.dy += ev.value * self.cfg.mouse_speed
                elif ev.code == e.REL_WHEEL:
                    self.mouse.wheel += ev.value
                elif ev.code == e.REL_HWHEEL:
                    self.mouse.hwheel += ev.value

            tracker = self.trackers.get(d.dev.path)
            if tracker and self.remote:
                for bit, down in tracker.handle(ev, self.mouse):
                    if down:
                        self.mouse.buttons |= bit
                    else:
                        self.mouse.buttons &= ~bit
                    self.mouse.dirty = True
                    rep = self.mouse.take_report()
                    if rep:
                        await self.t.send(MOUSE_REPORT_ID, rep)
            elif tracker:
                tracker.handle(ev, MouseState())

    async def _on_key(self, ev):
        e = self.e
        code, value = ev.code, ev.value

        # Museknapper
        if code in self.btnmap:
            if self.remote and value in (0, 1):
                bit = self.btnmap[code]
                if value:
                    self.mouse.buttons |= bit
                else:
                    self.mouse.buttons &= ~bit
                self.mouse.dirty = True
            return

        # Hold styr på hva som er fysisk nede. Bare ekte taster teller -
        # BTN_TOUCH fra en finger på touchpaden skal ikke blokkere modusbytte.
        if code < self.e.BTN_MISC:
            if value == 1:
                self.down.add(code)
            elif value == 0:
                self.down.discard(code)

        # Vekselkombinasjonen sendes videre som vanlig - den består av
        # rene modifiers og produserer ingen tegn i noen ende.
        if code in self.chord:
            await self._chord_update()

        if self.remote:
            await self._forward(code, value)

    async def _forward(self, code, value):
        if value == 2:  # autorepeat håndteres av verten
            return
        changed = False
        if code in self.modmap:
            bit = self.modmap[code]
            if value:
                self.kb.mods |= bit
            else:
                self.kb.mods &= ~bit
            changed = True
        else:
            usage = self.keymap.get(code)
            if usage is None:
                return
            changed = self.kb.press(usage) if value else self.kb.release(usage)
        if changed:
            report = self.kb.report()
            if self.debug:
                log(f"tast -> {report.hex(' ')}")
            await self.t.send(KEYBOARD_REPORT_ID, report)


# --------------------------------------------------------------------------
# Enhetsoppdagelse
# --------------------------------------------------------------------------

class Dev:
    def __init__(self, dev, kind):
        self.dev = dev
        self.kind = kind

    def __repr__(self):
        return f"<{self.kind}: {self.dev.path} {self.dev.name}>"


def discover(paths=None):
    from evdev import InputDevice, list_devices, ecodes as e

    found = []
    for path in (paths or sorted(list_devices())):
        try:
            dev = InputDevice(path)
        except OSError:
            continue
        # absinfo=False er vesentlig: med absinfo=True kommer EV_ABS som
        # (kode, AbsInfo)-tupler, og medlemskapstestene under slår aldri til.
        caps = dev.capabilities(absinfo=False)
        keys = set(caps.get(e.EV_KEY, []))
        rel = set(caps.get(e.EV_REL, []))
        abs_ = set(caps.get(e.EV_ABS, []))

        kind = None
        if {e.KEY_A, e.KEY_Z, e.KEY_ENTER} <= keys:
            kind = "keyboard"
        elif e.BTN_TOUCH in keys and {e.ABS_MT_POSITION_X,
                                      e.ABS_MT_POSITION_Y} <= abs_:
            kind = "touchpad"
        elif e.BTN_TOUCH in keys and {e.ABS_X, e.ABS_Y} <= abs_:
            kind = "touchpad"          # eldre pad uten multitouch
        elif e.BTN_LEFT in keys and {e.REL_X, e.REL_Y} <= rel:
            kind = "mouse"

        if kind:
            found.append(Dev(dev, kind))
        else:
            dev.close()
    return found


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def parse_args(argv=None):
    p = argparse.ArgumentParser(
        description="Gjør laptopen til et Bluetooth-tastatur og mus.")
    p.add_argument("--list", action="store_true",
                   help="list input-enheter og avslutt")
    p.add_argument("--status", action="store_true",
                   help="vis om bluetoothd er i vert- eller enhet-modus "
                        "og avslutt (krever ikke root)")
    p.add_argument("--device", action="append", metavar="PATH",
                   help="bruk kun denne /dev/input/eventN (kan gjentas)")
    p.add_argument("--adapter", default="hci0")
    p.add_argument("--name", default="Laptop Keyboard",
                   help="navnet gamingpcen ser under paring")
    p.add_argument("--connect", metavar="MAC",
                   help="koble ut mot en allerede paret vert ved oppstart")
    p.add_argument("--no-discoverable", action="store_true")
    p.add_argument("--toggle", default="KEY_LEFTSHIFT+KEY_RIGHTSHIFT",
                   metavar="CHORD",
                   help="tastekombinasjon som veksler lokal/remote, "
                        "evdev-navn skilt med + "
                        "(standard: begge shift-tastene)")
    p.add_argument("--toggle-hold", type=float, default=0.5,
                   help="sekunder kombinasjonen må holdes (standard 0.5)")
    p.add_argument("--mouse-speed", type=float, default=1.0)
    p.add_argument("--touchpad-speed", type=float, default=12.0,
                   help="piksler per mm på touchpaden")
    p.add_argument("--scroll-speed", type=float, default=0.6)
    p.add_argument("--natural-scroll", action="store_true")
    p.add_argument("--no-tap", action="store_true",
                   help="skru av tap-to-click på touchpaden")
    p.add_argument("--mouse-rate", type=float, default=125.0)
    p.add_argument("--setup", action="store_true",
                   help="konfigurer bluetoothd for HID-rollen (endrer "
                        "systemfiler og starter bluetooth.service på nytt)")
    p.add_argument("--undo", action="store_true",
                   help="brukes sammen med --setup for å reversere")
    p.add_argument("--yes", "-y", action="store_true",
                   help="ikke spør om bekreftelse ved --setup")
    p.add_argument("--debug", action="store_true",
                   help="logg rapportene som faktisk sendes")
    p.add_argument("--selftest", action="store_true",
                   help="valider descriptor og rapportpakking uten Bluetooth")
    return p.parse_args(argv)


def selftest():
    kb = KeyboardState()
    kb.mods = 0x02
    kb.press(0x04)
    assert kb.report() == bytes([0x02, 0, 0x04, 0, 0, 0, 0, 0]), kb.report()
    m = MouseState()
    m.dx, m.dy, m.wheel = 5.7, -3.2, 1
    rep = m.take_report()
    assert rep is not None and len(rep) == 7, rep
    xml = sdp_record("Test")
    assert REPORT_DESCRIPTOR.hex() in xml
    print(f"report descriptor: {len(REPORT_DESCRIPTOR)} bytes")
    print(f"tastaturrapport:   {len(kb.report())} bytes + report id")
    print(f"muserapport:       {len(rep)} bytes + report id")
    print(f"SDP-post:          {len(xml)} tegn")
    print("selftest OK")


# --------------------------------------------------------------------------
# Interaktivitet: enhetsvalg, auto-reconnect, REPL
# --------------------------------------------------------------------------

def pick_paired_device(bz: Bluez, console: Console) -> str | None:
    """Viser tidligere parrede enheter og lar brukeren velge en i stedet for
    å måtte skrive/huske en MAC-adresse. Returnerer None (vent på
    innkommende tilkobling) hvis det ikke finnes noen, eller brukeren bare
    trykker Enter."""
    devices = bz.paired_devices()
    if not devices:
        return None
    print("\nTidligere parrede enheter:")
    for i, dev in enumerate(devices, 1):
        status = "tilkoblet" if dev["connected"] else "ikke tilkoblet"
        print(f"  {i}. {dev['name']} ({dev['address']}) - {status}")
    svar = console.ask(
        "Koble til nummer (Enter for å vente på ny/innkommende tilkobling): ")
    if not svar:
        return None
    try:
        return devices[int(svar) - 1]["address"]
    except (ValueError, IndexError):
        print("Ugyldig valg, venter på innkommende tilkobling i stedet.")
        return None


async def reconnect_loop(transport: HidTransport, get_target):
    """Holder forbindelsen til target-MAC-en oppe: kobler til på nytt med
    stigende ventetid (opptil 30s) hvis den feiler eller faller, uten å
    polle - venter på transport.wait_disconnected() mellom forsøkene."""
    delay = 2
    while True:
        target = get_target()
        if target and not transport.connected:
            log(f"prøver å koble til {target} ...")
            ok = await transport.connect_to(target)
            if not ok:
                delay = min(delay * 2, 30)
                await asyncio.sleep(delay)
                continue
            delay = 2
        if transport.connected:
            await transport.wait_disconnected()
        else:
            await asyncio.sleep(2)


async def repl(console: Console, bz: Bluez, transport: HidTransport,
                router: "Router", target: dict):
    """Enkel kommandolinje i samme vindu mens btkbd kjører - slipper å
    restarte programmet for å koble til en annen enhet eller se status."""
    loop = asyncio.get_running_loop()
    print("\nSkriv 'help' for kommandoer mens btkbd kjører.")
    while True:
        line = await loop.run_in_executor(None, console.ask, "btkbd> ")
        if line is None:  # stdin stengt
            return
        parts = line.strip().split(maxsplit=1)
        if not parts:
            continue
        cmd, arg = parts[0].lower(), (parts[1] if len(parts) > 1 else "")

        if cmd in ("help", "?"):
            print("  list             - vis parrede enheter\n"
                  "  connect <nr|MAC> - koble til\n"
                  "  disconnect       - koble fra nåværende vert\n"
                  "  status           - vis modus og tilkobling\n"
                  "  toggle           - bytt LOKAL/REMOTE manuelt\n"
                  "  quit             - avslutt btkbd")
        elif cmd == "list":
            devices = bz.paired_devices()
            if not devices:
                print("  (ingen parrede enheter)")
            for i, dev in enumerate(devices, 1):
                status = "tilkoblet" if dev["connected"] else "ikke tilkoblet"
                print(f"  {i}. {dev['name']} ({dev['address']}) - {status}")
        elif cmd == "connect":
            if not arg:
                print("Bruk: connect <nummer eller MAC>")
                continue
            mac = arg
            if arg.isdigit():
                devices = bz.paired_devices()
                idx = int(arg) - 1
                if not (0 <= idx < len(devices)):
                    print("Ugyldig nummer, kjør 'list' først.")
                    continue
                mac = devices[idx]["address"]
            target["mac"] = mac
            print("Tilkoblet." if await transport.connect_to(mac)
                  else "Klarte ikke koble til - reconnect-løkken prøver videre.")
        elif cmd == "disconnect":
            await transport.disconnect()
            print("Koblet fra.")
        elif cmd == "status":
            print(f"  Modus:     {'REMOTE' if router.remote else 'LOKAL'}\n"
                  f"  Tilkoblet: {transport.peer or '(ingen)'}")
        elif cmd == "toggle":
            await router.set_remote(not router.remote)
        elif cmd in ("quit", "exit"):
            os.kill(os.getpid(), signal.SIGINT)
            return
        else:
            print(f"Ukjent kommando: {cmd} (skriv 'help')")


async def amain(cfg):
    preflight(cfg)

    devices = discover(cfg.device)
    if not devices:
        sys.exit("Fant ingen brukbare input-enheter. Kjører du som root?")
    for d in devices:
        log(f"bruker {d}")

    console = Console()

    bz = Bluez(cfg.adapter, cfg.name)
    bz.prepare_adapter(not cfg.no_discoverable)
    bz.register_profile()
    bz.register_agent(console)
    log(f"HID-profil registrert som «{cfg.name}»")

    transport = HidTransport()
    transport.listen()
    router = Router(transport, devices, cfg)
    transport.on_state_change = router.on_link_change

    # Mål-MAC for auto-reconnect. dict i stedet for en enkel variabel fordi
    # REPL-ens `connect`-kommando må kunne endre den underveis.
    target = {"mac": cfg.connect}
    if not target["mac"] and console.interactive:
        target["mac"] = pick_paired_device(bz, console)

    loop = asyncio.get_running_loop()
    stop = loop.create_future()

    def shutdown():
        if not stop.done():
            stop.set_result(None)

    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, shutdown)

    tasks = [
        asyncio.create_task(transport.accept_loop()),
        asyncio.create_task(router.run()),
        asyncio.create_task(reconnect_loop(transport, lambda: target["mac"])),
    ]
    if console.interactive:
        tasks.append(asyncio.create_task(repl(console, bz, transport, router, target)))

    log(f"klar. Hold {cfg.toggle} i {cfg.toggle_hold}s og slipp for å bytte.")
    try:
        await stop
    finally:
        await router.set_remote(False)
        for t in tasks:
            t.cancel()
        log("avsluttet")


def main():
    cfg = parse_args()
    if cfg.selftest:
        selftest()
        return
    if cfg.setup:
        run_setup(cfg.undo, cfg.yes)
        return
    if cfg.status:
        print_status()
        return
    if cfg.list:
        for d in discover(cfg.device):
            print(f"{d.kind:9} {d.dev.path:20} {d.dev.name}")
        return
    if os.geteuid() != 0:
        sys.exit("Må kjøres som root (L2CAP-porter og /dev/input).")
    try:
        asyncio.run(amain(cfg))
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
