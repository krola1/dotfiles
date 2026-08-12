# modules-mirror

## Tanken bak

1:1-speiling av seksjonene som allerede fantes i den originale `config.kdl`
(kommentar-bannerne `GLOBALS`, `INPUT`, `OUTPUTS`, osv.). Ingen omtolkning av
hva som "hører sammen" — bare én fil per seksjon niri selv allerede skiller
mellom. Laveste risiko, lettest å sammenligne mot originalen.

## Struktur

| Fil | Innhold |
|---|---|
| `globals.kdl` | `prefer-no-csd`, `hotkey-overlay`, `screenshot-path`, `animations` |
| `input.kdl` | tastatur, touchpad, mus, trackpoint |
| `outputs.kdl` | skjermoppsett (eDP-1, DP-1, HDMI-A-1, DP-2) |
| `layout.kdl` | gaps, focus-ring, border, shadow, struts, tabs |
| `gestures.kdl` | hot-corners |
| `startup.kdl` | `spawn-at-startup` / `environment` |
| `window-rules.kdl` | generiske og app-spesifikke vindusregler |
| `binds.kdl` | hele keybind-blokken, uendret |
| `main.kdl` | **inngangsporten** — `include`-er de 8 filene over i riktig rekkefølge |

Innholdet er verifisert byte-for-byte likt originalen (normalisert diff = 0
linjer avvik) og validert med `niri validate`.

## Bruk

### Midlertidig testing (endrer ingenting i din ekte config)

`main.kdl` er laget for å kjøres direkte, uten å røre `~/.config/niri/config.kdl`:

```fish
niri validate -c ~/dotfiles/niri/.config/niri/modules-mirror/main.kdl
```

For å faktisk se den kjøre (nested niri i et vindu, inni din nåværende session):

```fish
niri -c ~/dotfiles/niri/.config/niri/modules-mirror/main.kdl
```

Merk i nested-modus:
- `Mod` blir **Alt** i stedet for Super, for å unngå kollisjon med host-sesjonens binds.
- `Ctrl+Alt+Delete` er bundet til `quit` og bruker ikke `Mod` — det er raskeste vei ut av den nestede instansen uansett remapping.
- Niri live-reloader automatisk når du lagrer en av modulfilene, så du kan endre `layout.kdl` e.l. og se det slå inn med en gang i det nestede vinduet.

### Gjøre permanent

Anbefalt (minimal, reversibel — bytter bare ut selve inngangsporten):

```fish
cd ~/dotfiles/niri/.config/niri
cp config.kdl config.kdl.bak
echo 'include "modules-mirror/main.kdl"' > config.kdl
niri validate -c config.kdl
```

`config.kdl.bak` er sikkerhetsnett i tillegg til git-historikken. Å rulle
tilbake er enten `git checkout -- config.kdl` eller `mv config.kdl.bak config.kdl`.

Alternativ (fjerner ett indirection-nivå — flytter modulene opp og lar dem
*være* configen, uten mellomlagget `main.kdl`):

```fish
cd ~/dotfiles/niri/.config/niri
mv config.kdl config.kdl.bak
mv modules-mirror/main.kdl config.kdl
mv modules-mirror/*.kdl .
rmdir modules-mirror
niri validate -c config.kdl
```

Denne varianten er mer disruptiv (endrer filstrukturen permanent), så bruk
den bare når du er sikker på at `mirror`-oppdelingen er den du vil beholde.
