# btkbd

Gjør laptopen til et ekte Bluetooth-tastatur og mus. Gamingpcen ser den som en
helt vanlig HID-enhet — ingen programvare på mottakersiden, virker også i BIOS
og på maskiner uten nett.

## Avhengigheter

```fish
sudo pacman -S python-dbus python-gobject python-evdev bluez bluez-utils
```

## 1. Konfigurer BlueZ

Trengs bare første gang (eller etter en BlueZ-oppdatering som nullstiller
drop-in-fila). Kjører du `sudo ./btkbd.py` og input-pluginet fortsatt er
aktivt, oppdager btkbd det selv ved oppstart, viser nøyaktig hva den vil
endre, spør om bekreftelse, og kjører oppsettet før den fortsetter — du
trenger ikke kjøre `--setup` manuelt først. Vil du gjøre det som et eget
steg (f.eks. for å ha unnagjort restarten i forkant), går det fortsatt fint:

```fish
sudo ./btkbd.py --setup
```

`setup-bluez.sh` er bare en wrapper rundt samme kommando.

Oppsettet gjør to ting: deaktiverer `input`-pluginet i `bluetoothd` (som ellers
okkuperer L2CAP-portene 17 og 19 fordi den normalt *tar imot* tastaturer), og
setter Class of Device til `0x0025C0` slik at Windows gjenkjenner deg som
tastatur + pekeenhet.

> Mens dette er aktivt kan ikke laptopen selv bruke Bluetooth-tastatur eller
> -mus. BT-lyd er upåvirket — det er en annen plugin.
> `sudo ./btkbd.py --setup --undo` reverserer alt.

Det skriver til `/etc` og starter `bluetooth.service` på nytt — en omstart
som kobler ned hodetelefoner og alt annet som er tilkoblet der og da. Det er
en systemendring som lever videre etter at programmet er avsluttet, derfor
spør den før den gjør det, selv når den kjøres automatisk fra vanlig
oppstart. Har du automatisert oppsettet ditt (f.eks. som tjeneste), tar
`--yes` bort bekreftelsen også i det automatiske løpet.

## 2. Start

```fish
sudo ./btkbd.py --list          # se hvilke enheter som plukkes opp
sudo ./btkbd.py --name "Lars laptop"
```

Har du parret med noe før, spør btkbd deg med en gang om hvilken av de
tidligere parrede enhetene du vil koble til (nummer), eller Enter for å
bare vente på en innkommende tilkobling.

## 3. Par med gamingpcen

Start `btkbd.py` **først** — SDP-posten må være publisert før Windows kan se
deg som tastatur. Så, på gamingpcen: Innstillinger → Bluetooth → Legg til enhet.

Windows viser en sekssifret kode og ber deg "skrive den på tastaturet". Det
trengs ikke noe eget terminalvindu for dette — btkbd registrerer sin egen
pairing-agent, så koden skrives rett i vinduet der `btkbd.py` allerede kjører:

```
[btkbd] Skriv koden verten viser: _
```

Etterpå kan du hoppe over paringen og koble rett opp, enten med flagget:

```fish
sudo ./btkbd.py --connect AA:BB:CC:DD:EE:FF
```

eller mens programmet kjører, skriv `connect AA:BB:CC:DD:EE:FF` (eller
`connect <nummer>` fra `list`) i selve btkbd-vinduet - se «Mens den kjører»
under.

Er `--connect` satt (eller valgt fra listen ved oppstart), holder btkbd
forbindelsen oppe selv: faller den, eller feiler den ved oppstart, prøver den
på nytt automatisk med økende mellomrom (2s, 4s, 8s ... opptil 30s) til den
lykkes.

## 4. Bruk

Programmet starter i **LOKAL** modus — ingenting videresendes.

**Hold begge shift-tastene i et halvt sekund og slipp** for å veksle mellom
LOKAL og REMOTE. I REMOTE går alt — taster, touchpad, TrackPoint, mus — til
gamingpcen, og ingenting til Niri.

Shift+Shift er valgt fordi det er to rene modifiers: kombinasjonen produserer
ingen tegn og treffer ingen snarvei, verken i Niri eller på gamingpcen, så det
gjør ingenting at den lekker gjennom. Shift fungerer fortsatt som shift.

Selve byttet skjer på *slipp*, ikke når holdetiden er nådd — du får en
«klar»-melding når den er armert. Grunnen er at kompositoren må rekke å se
både trykk og slipp; bytter vi midt i et trykk, blir shift hengende i Niri.

Vil du ha noe annet, tar `--toggle` en hvilken som helst kombinasjon av
evdev-navn:

```fish
sudo ./btkbd.py --toggle KEY_LEFTCTRL+KEY_LEFTALT+KEY_LEFTSHIFT
sudo ./btkbd.py --toggle KEY_RIGHTALT+KEY_LEFTMETA
```

Hold deg til rene modifiers (`KEY_LEFTCTRL`, `KEY_LEFTSHIFT`, `KEY_LEFTALT`,
`KEY_LEFTMETA`, `KEY_RIGHTSHIFT`, `KEY_RIGHTALT`, `KEY_RIGHTMETA`). Bruker du
en vanlig tast, får både Niri og gamingpcen den også — programmet advarer ved
oppstart. `KEY_CAPSLOCK` er teknisk mulig, men da slår caps lock seg på lokalt
hver gang du bytter.

Sikkerhetsnett:

- Overtakelsen skjer bare når ingen taster er nede, så Niri sitter aldri igjen
  med en «hengende» modifier. Holder du en annen tast når du slipper
  kombinasjonen, avbrytes byttet.
- Ved bytte tilbake sendes en tom rapport først, slik at ingen tast blir
  stående nede på gamingpcen.
- Faller Bluetooth-forbindelsen, slippes tastaturet automatisk.
- Ctrl-C eller `systemctl stop` slipper også alltid.
- Verste fall: SSH inn fra mobilen og `sudo pkill -f btkbd`.

## Mens den kjører

Kjører du interaktivt (ikke som tjeneste), tar btkbd-vinduet imot enkle
kommandoer i tillegg til status-linjene:

| Kommando | Effekt |
|---|---|
| `list` | vis parrede enheter |
| `connect <nr\|MAC>` | koble til - nummer fra `list`, eller en MAC direkte |
| `disconnect` | koble fra nåværende vert |
| `status` | vis modus (LOKAL/REMOTE) og hvem den er tilkoblet |
| `toggle` | bytt LOKAL/REMOTE uten å bruke tastekombinasjonen |
| `quit` | avslutt btkbd (samme som Ctrl-C) |

Kjører btkbd som tjeneste (ingen tty), er verken parrings-agenten, enhets-
velgeren eller kommandolinjen tilgjengelig - de krever et terminalvindu å
spørre i. Par først interaktivt, så holder `--connect` i unit-fila
forbindelsen oppe automatisk med reconnect-logikken beskrevet i punkt 3.

## Tastaturlayout

Programmet sender HID-usage-koder, altså *posisjoner*, ikke tegn. Verten
bestemmer layouten. Har gamingpcen norsk layout, får du `ø æ å` der du
forventer. Har den amerikansk, får du `; ' [`. `KEY_102ND` (`<>|`-tasten ved
venstre shift) er med, så den fungerer også.

## Nyttige flagg

| Flagg | Effekt |
|---|---|
| `--device /dev/input/event3` | bruk bare bestemte enheter (kan gjentas) |
| `--toggle KEY_LEFTCTRL+KEY_LEFTALT` | annen vekselkombinasjon |
| `--toggle-hold 1.0` | lengre hold før armering |
| `--touchpad-speed 18` | raskere touchpad |
| `--natural-scroll` | snu scrolleretningen |
| `--no-tap` | skru av tap-to-click |
| `--mouse-rate 200` | flere muserapporter per sekund |
| `--debug` | logg rapportene som faktisk sendes |
| `--selftest` | validerer rapportpakking uten Bluetooth |
| `--status` | vis vert/enhet-modus og avslutt (krever ikke root) |

## Som tjeneste

```fish
sudo cp btkbd.py /usr/local/bin/btkbd
sudo cp btkbd.service /etc/systemd/system/
sudo systemctl enable --now btkbd
```

Rediger `--connect`-adressen i unit-fila først. Merk at du da mister
statuslinjene i terminalen — `journalctl -fu btkbd` viser dem.

## Feilsøking

**`UUID already registered`** eller **`PSM 17 er opptatt`** — input-pluginet
kjører fortsatt. Begge deler har samme årsak: pluginet eier både HID-UUID-en
og portene. Verifiser med:

```fish
./btkbd.py --status
```

Sier den `vert`, har ikke drop-in-fila slått inn. Kjør `sudo ./btkbd.py --setup` og
`sudo systemctl restart bluetooth`. Programmet sjekker dette selv ved
oppstart og kjører oppsettet automatisk (etter bekreftelse) hvis pluginet
fortsatt er aktivt — denne feilen dukker typisk bare opp i et race der
pluginet blir aktivert igjen *etter* at btkbd allerede har startet.

**Windows ser enheten, men som "ukjent"** — Class of Device er ikke satt.
Sjekk `Class` i `/etc/bluetooth/main.conf` og restart `bluetooth`.

**Paret, men ingen forbindelse** — Windows kobler ofte ikke ut av seg selv.
Bruk `--connect <MAC>`, eller klikk på enheten i Windows sin Bluetooth-liste.

**Forbindelsen faller etter noen sekunder** — verten fikk ikke svar på
control-kanalen. Kjør `sudo btmon` i et annet vindu og se hva som sendes rett
før nedkoblingen.

**Pekeren blir værende på laptopen** — sjekk at `sudo ./btkbd.py --list` viser
en linje av typen `touchpad`. Gjør den ikke det, brukes en enhet programmet
ikke kjenner igjen; send utskriften av `sudo libinput list-devices | grep -A2 Kernel`
så utvider jeg gjenkjenningen. `--debug` viser rapportene som faktisk sendes.

**Musen henger etter** — Bluetooth Classic har rundt 7–10 ms latens i praksis.
Godt nok til å skrive og navigere, ikke godt nok til å sikte i Skyrim.
