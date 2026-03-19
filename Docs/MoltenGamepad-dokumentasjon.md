# MoltenGamepad – Brukerdokumentasjon

MoltenGamepad er en daemon som leser input-enheter (kontrollere, gamepads o.l.) og videresender dem som virtuelle gamepads som spillprogramvare forstår. Den lar deg remmappe knapper og akser, kombinere input-enheter, og sørge for at kontrollere «bare fungerer» – selv om de kobles fra og til igjen.

---

## Innholdsfortegnelse

1. [Konsepter og terminologi](#1-konsepter-og-terminologi)
2. [Konfigurasjonsfiler og mappestruktur](#2-konfigurasjonsfiler-og-mappestruktur)
3. [Opprette en generisk driver (gendev)](#3-opprette-en-generisk-driver-gendev)
4. [Default gamepad-profil – referanse for navn](#4-default-gamepad-profil--referanse-for-navn)
5. [Profiler og event-mapping](#5-profiler-og-event-mapping)
6. [Output-slots](#6-output-slots)
7. [Oppstart og konfigurasjonsfil](#7-oppstart-og-konfigurasjonsfil)
8. [Kjøre og sende kommandoer](#8-kjøre-og-sende-kommandoer)
9. [Avansert: Gruppe-translators](#9-avansert-gruppe-translators)

---

## 1. Konsepter og terminologi

Før du konfigurerer noe er det nyttig å ha et klart bilde av hvordan MoltenGamepad (MG) er bygget opp.

```
[Fysisk enhet] → [Driver/gendev] → [Input source] → [Profil] → [Output slot / virtuell gamepad]
```

**Input source** er MGs representasjon av en fysisk enhet. Én input source kan komme fra én fysisk enhet, eller en enhet kan splittes til flere input sources.

**Driver** er koden som forstår en bestemt type enhet. MG har én innebygd driver for Wii-remotes. For alle andre enheter lager du en *generisk driver* via en `.cfg`-fil (se seksjon 3).

**Profil** inneholder alle event-mappinger for en driver eller enhet. Profiler arver fra hverandre i et hierarki:

```
gamepad (rot-profil)
 ├── <driver-profil>
 │    ├── <enhet-profil>
 │    └── <enhet-profil>
 └── <driver-profil>
      └── <enhet-profil>
```

Endringer i en driver-profil propagerer automatisk ned til alle tilkoblede enheter. Endringer i rot-profilen `gamepad` propagerer til alle drivere som abonnerer på den (standard for alle gamepads).

**Output slot** er de virtuelle gamepad-enhetene som opprettes av MG, navngitt `virtpad1`, `virtpad2` osv. Det er disse spillene faktisk leser fra. Som standard opprettes 4 virtuelle gamepads, ett tastatur-slot (`keyboard`), og et tomt dummy-slot (`blank`).

---

## 2. Konfigurasjonsfiler og mappestruktur

MG følger XDG-spesifikasjonen. Med standardverdier betyr det:

| Formål | Bruker-spesifikk | Systemomfattende |
|---|---|---|
| Konfig-rotmappe | `~/.config/moltengamepad/` | `/etc/xdg/moltengamepad/` |
| Generiske drivere | `~/.config/moltengamepad/gendevices/` | `/etc/xdg/moltengamepad/gendevices/` |
| Profiler | `~/.config/moltengamepad/profiles/` | `/etc/xdg/moltengamepad/profiles/` |
| Oppstartsinnstillinger | `~/.config/moltengamepad/moltengamepad.cfg` | `/etc/xdg/moltengamepad/moltengamepad.cfg` |
| Dynamiske innstillinger | `~/.config/moltengamepad/options/*.cfg` | `/etc/xdg/moltengamepad/options/*.cfg` |

---

## 3. Opprette en generisk driver (gendev)

Dette er det første du trenger å gjøre etter installasjon hvis du ikke bruker en Wii-remote. En generisk driver forteller MG hvilken enhet som skal håndteres, og hva de ulike event-kodene fra enheten heter.

Filen lagres i `gendevices/`-mappen, f.eks. `~/.config/moltengamepad/gendevices/mincontroller.cfg`.

### 3.1 Finn event-koder for enheten din

Installer `evtest` og kjør det:

```bash
sudo evtest
```

Velg enheten din fra listen, trykk på knapper og beveg akser. Du vil se output som:

```
Event: time 1234567890.123, type 1 (EV_KEY), code 304 (BTN_SOUTH), value 1
Event: time 1234567890.456, type 3 (EV_ABS), code 0 (ABS_X), value -32767
```

Noter ned event-navnene (f.eks. `btn_south`, `abs_x`) for alle innganger du ønsker å bruke. Øverst i `evtest`-output finner du også vendor-ID og product-ID:

```
Input device ID: bus 0x3 vendor 0x045e product 0x028e version 0x110
```

### 3.2 Struktur på en gendev-fil

En gendev-fil har fire deler:

```ini
# Del 1: Hvilken enhet skal denne driveren gjenkjenne?
["Enhetens navn slik det rapporteres"]

# Del 2: Drivernavn og innstillinger
name = "mindriver"       # Navn på driveren i MG
devname = "pad"          # Prefiks for enhetsnavn (pad1, pad2, ...)
exclusive = "true"       # Skjul originalenheten fra annen programvare

# Del 3: Event-definisjoner  (<evdev-kode> = "<internt navn>","<beskrivelse>")
btn_south = "first",    "Primærknapp"
btn_east  = "second",   "Sekundærknapp"
abs_x     = "left_x",  "Venstre stikk X-akse"

# Del 4: Aliaser (kobler enhetens navn til gamepad-profilens navn)
alias first  first
alias second second
```

### 3.3 Enhetsmatch

Den enkleste måten å matche en enhet på er via det rapporterte navnet:

```ini
["Microsoft X-Box 360 pad"]
```

Du kan også kombinere flere felt (alle må matche):

```ini
[name="Microsoft X-Box 360 pad" vendor=045e product=028e]
```

Tilgjengelige match-felt:

| Felt | Beskrivelse |
|---|---|
| `name` | Enhetens rapporterte navn (streng) |
| `vendor` | Vendor-ID i hex |
| `product` | Product-ID i hex |
| `driver` | Navn på Linux-driveren |
| `events` | `superset`, `subset` eller `exact` – sammenligner event-listen |
| `min_common_events` | Minimum antall felles events ved `subset`-match |
| `order` | Prioritet ved overlappende match (lavere tall = høyere prioritet) |

Flere match-linjer i rad definerer alternative enheter under **samme driver**. To separate match-blokker (med noe annet imellom) definerer **to separate drivere**.

### 3.4 Drivernavn og innstillinger

```ini
name = "mindriver"          # Drivernavnet brukt i MG-kommandoer
devname = "pad"             # Prefiks for tilkoblede enheter: pad1, pad2, ...
exclusive = "true"          # Stjeler events – originalenheten fremstår som stille
change_permissions = "true" # Blokkerer tilgang til originalenheten helt (krever eierskap via udev)
flatten = "false"           # Koaleser alle matchende enheter til én input source
rumble = "false"            # Videreformidl rumble-events (krever --rumble ved oppstart)
split = 1                   # Antall input sources fra én enhet (for arcade-sticks o.l.)
device_type = "gamepad"     # "gamepad" (standard), "keyboard", eller egendefinert streng
```

> **Merk om `change_permissions`:** Krever at din bruker er eier av enhetsnoden. Dette settes opp via udev-reglene fra installasjonsprosessen.

### 3.5 Event-definisjoner

Format: `<evdev-kode> = "<internt navn>","<beskrivelse>"`

```ini
btn_south  = "first",    "Primærknapp (Bekreft)"
btn_east   = "second",   "Sekundærknapp (Tilbake)"
abs_x      = "left_x",  "Venstre stikk X-akse"
abs_y      = "left_y",  "Venstre stikk Y-akse"
```

Hvis du trenger å spesifisere event ved nummer i stedet for navn:

```ini
key(304) = "first", "Primærknapp"   # btn_south = key-kode 304
abs(0)   = "left_x", "Venstre X"    # abs_x = abs-kode 0
```

### 3.6 Aliaser – koble til gamepad-profilen

> **Dette er den viktigste og mest oversette delen.** Forstår du dette, forstår du MoltenGamepad.

Når `device_type = "gamepad"` (standardverdien), abonnerer driveren automatisk på **rot-profilen `gamepad`**. Denne profilen inneholder standardmappinger som sender events videre til riktige output-koder.

`gamepad`-profilen bruker bestemte event-navn. Enheten din bruker dine egne interne navn. **Aliaser er broen mellom disse.**

**Eksempel:** Gamepad-profilen kjenner til `first` som primærknappen. Enheten din har `cross` som internt navn for den samme knappen. Da legger du til:

```ini
alias first cross
```

Dette betyr: «Når gamepad-profilen forsøker å konfigurere `first`, bruk mitt event `cross` i stedet.»

Uten aliaser vil ikke mappingene fra gamepad-profilen ha noen effekt på enheten din.

### 3.7 Referanse: gamepad-profilens event-navn

Dette er alle navnene gamepad-profilen forstår. Du trenger aliaser for de navnene som ikke allerede matcher dine egne event-navn.

**Knapper:**

| Gamepad-profilnavn | Evdev-kode | Beskrivelse |
|---|---|---|
| `first` | `BTN_SOUTH` | Primærknapp (Bekreft) |
| `second` | `BTN_EAST` | Sekundærknapp (Tilbake) |
| `third` | `BTN_WEST` | Tredje ansiktsknapp |
| `fourth` | `BTN_NORTH` | Fjerde ansiktsknapp |
| `up` | `BTN_DPAD_UP` | D-pad opp |
| `down` | `BTN_DPAD_DOWN` | D-pad ned |
| `left` | `BTN_DPAD_LEFT` | D-pad venstre |
| `right` | `BTN_DPAD_RIGHT` | D-pad høyre |
| `start` | `BTN_START` | Start |
| `select` | `BTN_SELECT` | Select |
| `mode` | `BTN_MODE` | Logo/Guide/Home-knapp |
| `tl` | `BTN_TL` | Øvre venstre skulderknapp (L1/LB) |
| `tr` | `BTN_TR` | Øvre høyre skulderknapp (R1/RB) |
| `tl2` | `BTN_TL2` | Nedre venstre trigger, digital (kun uten analoge triggere) |
| `tr2` | `BTN_TR2` | Nedre høyre trigger, digital (kun uten analoge triggere) |
| `thumbl` | `BTN_THUMBL` | Venstre stikk-klikk (L3) |
| `thumbr` | `BTN_THUMBR` | Høyre stikk-klikk (R3) |
| `tl2_axis_btn` | – | Digital event fra analog trigger – ignoreres normalt |
| `tr2_axis_btn` | – | Digital event fra analog trigger – ignoreres normalt |

**Akser:**

| Gamepad-profilnavn | Evdev-kode | Beskrivelse |
|---|---|---|
| `left_x` | `ABS_X` | Venstre stikk X-akse |
| `left_y` | `ABS_Y` | Venstre stikk Y-akse |
| `right_x` | `ABS_RX` | Høyre stikk X-akse |
| `right_y` | `ABS_RY` | Høyre stikk Y-akse |
| `tl2_axis` | `ABS_Z` | Venstre trigger, analog verdi |
| `tr2_axis` | `ABS_RZ` | Høyre trigger, analog verdi |
| `updown` | `ABS_HAT0Y` | D-pad opp/ned som hat-akse |
| `leftright` | `ABS_HAT0X` | D-pad venstre/høyre som hat-akse |

> **`tl2` vs. `tl2_axis`:** Hvis enheten har **analoge** triggere, bruk `tl2_axis`/`tr2_axis` for de analoge verdiene, og map `tl2_axis_btn`/`tr2_axis_btn` til `nothing`. Hvis enheten kun har **digitale** triggere, bruk `tl2`/`tr2`.

**Bakoverkompatibilitetsaliaser:**

| Alias | Peker til |
|---|---|
| `primary` | `first` |
| `secondary` | `second` |

### 3.8 Komplett eksempel – Xbox 360-kontroller

```ini
["Microsoft X-Box 360 pad"]

name    = "xbox360"
devname = "xbox"
exclusive = "true"

# Ansiktsknapper
btn_south = "a",      "A-knapp"
btn_east  = "b",      "B-knapp"
btn_west  = "x",      "X-knapp"
btn_north = "y",      "Y-knapp"

# Skulder og triggere
btn_tl    = "lb",       "Venstre skulder"
btn_tr    = "rb",       "Høyre skulder"
abs_z     = "lt_axis",  "Venstre trigger, analog"
abs_rz    = "rt_axis",  "Høyre trigger, analog"
btn_tl2   = "lt",       "Venstre trigger, digital"
btn_tr2   = "rt",       "Høyre trigger, digital"

# Stikker
abs_x     = "left_x",   "Venstre stikk X"
abs_y     = "left_y",   "Venstre stikk Y"
abs_rx    = "right_x",  "Høyre stikk X"
abs_ry    = "right_y",  "Høyre stikk Y"
btn_thumbl = "l3",      "Venstre stikk-klikk"
btn_thumbr = "r3",      "Høyre stikk-klikk"

# D-pad
abs_hat0x = "leftright", "D-pad venstre/høyre"
abs_hat0y = "updown",    "D-pad opp/ned"

# Meny-knapper
btn_start  = "start",   "Start"
btn_select = "back",    "Back"
btn_mode   = "guide",   "Xbox Guide"

# Aliaser til gamepad-profil
# (Events som allerede heter det samme trenger ikke alias)
alias first    a
alias second   b
alias third    x
alias fourth   y

alias tl       lb
alias tr       rb
alias tl2_axis    lt_axis
alias tr2_axis    rt_axis
alias tl2_axis_btn lt
alias tr2_axis_btn rt

alias thumbl   l3
alias thumbr   r3
alias start    start
alias select   back
alias mode     guide
```

> **Tips:** Events som allerede har riktig navn (f.eks. `left_x`, `left_y`, `right_x`, `right_y`, `leftright`, `updown`) trenger ingen alias – de matcher gamepad-profilens navn direkte.

---

## 4. Default gamepad-profil – referanse for navn

*(Se seksjon 3.7 for den komplette tabellen.)*

Gamepad-profilen er rot-profilen alle gamepad-drivere arver fra. Den definerer standardmappinger fra logiske event-navn til virtuelle output-koder. Driveren din trenger aliaser for å fortelle profilen hvilke av dine event-navn som svarer til profilnavnene.

---

## 5. Profiler og event-mapping

### 5.1 Endre en mapping

Syntaks for å endre en mapping:

```
<profil>.<event-navn> = <output-event>
```

**Eksempler:**

```
# Endre for alle enheter i en driver på én gang:
xbox360.a = select

# Endre bare for én bestemt enhet:
xbox1.a = start

# Endre for alle gamepads via rot-profilen:
gamepad.select = start

# Fjern en mapping (send ingenting):
xbox360.a = nothing
```

Endringer til en driver-profil propagerer til alle tilkoblede og fremtidige enheter fra den driveren. Endringer til en enhets-profil gjelder kun den spesifikke enheten.

### 5.2 Mulige output-events

**Knapper:**
`first`, `second`, `third`, `fourth`, `start`, `select`, `mode`, `lt`, `lt2`, `tr`, `tr2`, `thumbl`, `thumbr`, `up`, `down`, `left`, `right`

**Akser:**
`left_x`, `left_y`, `right_x`, `right_y`, `tl2_axis`, `tr2_axis`, `leftright`, `updown`

Alle evdev-koder er også tilgjengelige som output ved å bruke små bokstaver:
`btn_south`, `abs_x`, `key_a`, `key_esc`, osv.

### 5.3 Mapping-typer

**Knapp → knapp:**
```
xbox360.a = first
```

**Akse → akse** (+ eller - for retning):
```
xbox360.left_x = left_x
xbox360.left_x = left_x-    # invertert
```

**Knapp → akse** (knappen setter aksen til maks i valgt retning):
```
xbox360.a = left_x+
```

**Akse → to knapper** (negativ ytterpunkt = første knapp, positiv = andre):
```
xbox360.left_x = left,right
```

**Knapp → relativ event** (genererer events periodisk mens den holdes):
```
xbox360.a = rel_x+
```

**Omvendt input** (legg til `-` på slutten av input-event-navn):
```
xbox360.left_x- = right_x    # inverter input-aksen
```

**Flere outputs fra én input:**
```
xbox360.a = multi(start,select)
```

**Omdirigere til tastaturslot:**
```
xbox360.a = key(key_a)
```

**Omdirigere til musepeker:**
```
xbox360.left_x = mouse(rel_x)
```

### 5.4 Profil-kommandoer

```
print profiles              # List alle aktive profiler
print profiles xbox360      # Vis alle mappinger i xbox360-profilen
print events xbox360        # Vis alle events en driver/enhet eksponerer
print aliases xbox360       # Vis alle aliaser for en driver/enhet
print devices xbox1         # Vis informasjon om en enhet, inkl. events
```

### 5.5 Lagre og laste profiler

```
save profiles to "minprofil"    # Lagrer alle driver-profiler til profiles/minprofil
load profiles from "minprofil"  # Laster profil-fil
```

**Headers i profil-filer** – lar deg gruppere mappinger:

```ini
[xbox360]
a = first
b = second
left_x = left_x
left_y = left_y
```

Det er ekvivalent med å skrive `xbox360.a = first` osv., men mer lesbart i filer.

---

## 6. Output-slots

Output-slots er de virtuelle enhetene som spillene leser fra. Som standard:

- `virtpad1` til `virtpad4` – virtuelle gamepads
- `keyboard` – virtuelt tastatur
- `blank` – tomt dummy-slot (ignorerer alle events)

En input source tildeles automatisk det første ledige virtpadslottet ved første «merkbare» event (knapptrykk eller stor aksebevegelse).

### 6.1 Flytte enheter mellom slots

```
move xbox1 to virtpad2     # Flytt til et spesifikt slot
move xbox1 to nothing      # Fjern fra alle slots
move xbox1 to auto         # Tving automatisk tildeling
move all to nothing        # Fjern alle enheter fra slots
print slots                # Se alle slots og hva de inneholder
print devices              # Se alle tilkoblede enheter
```

### 6.2 Slot-innstillinger

Vises med `print options slots`, endres med `set slots <navn> = <verdi>`:

| Innstilling | Beskrivelse |
|---|---|
| `auto_assign` | Om enheter automatisk tildeles slot ved oppstart (true/false) |
| `active_pads` | Maks antall slots å vurdere ved automatisk tildeling |
| `min_pads` | Minimum antall åpne virtpads |
| `press_start_on_disconnect` | Send virtuell start-knapp når en enhet kobles fra (`any`/`last`/off) |
| `press_start_ms` | Varighet i ms for den virtuelle start-knapp-eventen |

---

## 7. Oppstart og konfigurasjonsfil

### 7.1 moltengamepad.cfg

Opprettede i `~/.config/moltengamepad/moltengamepad.cfg`. Samme alternativer som kommandolinjeargumenter, men med understrek i stedet for bindestrek:

```ini
# ~/.config/moltengamepad/moltengamepad.cfg

# Gjør virtuelle gamepads se ut som Xbox 360-kontrollere (anbefalt)
mimic_xpad = true

# Opprett en FIFO for scripting
make_fifo = true

# Last inn egne profil-mappinger ved oppstart
load profiles from "mine_mappinger"
```

Se alle tilgjengelige alternativer med:
```bash
moltengamepad --print-cfg
```

### 7.2 Dynamiske innstillinger (options/*.cfg)

For innstillinger som kan endres mens MG kjører, opprett `.cfg`-filer i `options/`-mappen. Filnavnet tilsvarer kategorinavnet:

```ini
# ~/.config/moltengamepad/options/slots.cfg
auto_assign = true
```

---

## 8. Kjøre og sende kommandoer

```bash
moltengamepad                    # Start normalt
moltengamepad --mimic-xpad       # Anbefalt: se ut som Xbox 360
moltengamepad --help             # Vis alle argumenter
```

### 8.1 Interaktive kommandoer

MG leser kommandoer fra standard input mens det kjører:

```
help                        # Vis tilgjengelige kommandoer
print drivers               # Vis alle lastede drivere
print profiles              # Vis alle profiler
print slots                 # Vis output-slots og tilknyttede enheter
print devices               # Vis alle tilkoblede input sources
print events <driver>       # Vis events for en driver/enhet
print options slots         # Vis slot-innstillinger
set slots auto_assign = true
```

### 8.2 Sende kommandoer til en kjørende instans

**Via FIFO** (enveis, kun sende kommandoer):
```bash
moltengamepad --make-fifo   # Opprett FIFO ved oppstart
echo "gamepad.select = start" > /path/to/fifo
```

**Via socket** (toveis, krever klient som `moltengamepadctl`):
```bash
moltengamepad --make-socket
```

---

## 9. Avansert: Gruppe-translators

Noen mappinger trenger å lese to events samtidig, f.eks. for å håndtere et tommelstikk med deadzone korrekt.

### Tommelstikk

```
xbox360.(left_x,left_y) = stick(left_x,left_y)
xbox360.(right_x,right_y) = stick(right_x,right_y)
```

`stick`-translatoren ser på begge aksene samtidig og filtrerer bort jitter innenfor dødsonene. Dette er standardmappingen i gamepad-profilen, og settes automatisk opp dersom enheten din har `left_x`/`left_y`-aliaser.

### D-pad fra analog hat

```
xbox360.(leftright,updown) = dpad
```

Konverterer en hat-akse til digitale d-pad-events.

### Slett en gruppe-mapping

```
xbox360.(left_x,left_y) = nothing
```

### Aliaser for grupper

En alias kan peke til en gruppe av events, slik at man kan skrive kortere:

```
xbox360.left_stick = dpad    # left_stick er et alias for (left_x,left_y)
```

### Akkorder (chord)

```
xbox360.(a,b) = chord(tr)        # Sender tr når BÅDE a og b er holdt inne
xbox360.(a,b) = exclusive(tr)    # Som chord, men a og b sendes IKKE separat
```