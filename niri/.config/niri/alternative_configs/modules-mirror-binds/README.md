# modules-mirror-binds

## Tanken bak

Samme som `modules-mirror`, men `binds.kdl` — som alene utgjorde ca. 64 % av
den originale filen (470 av 733 linjer) — er sprengt videre ut i en egen
`binds/`-undermappe. Den originale bind-blokken hadde allerede 11 tydelige
kommentar-grupper, så det var en naturlig deling fremfor å la én enkelt fil
dominere hele modul-settet.

Hver fil i `binds/` inneholder sin *egen* selvstendige `binds { ... }`-blokk.
Dette er verifisert å fungere: niri slår sammen `binds`-blokker fra flere
inkluderte filer additivt (`niri validate` godkjenner det, og en normalisert
diff mot originalen viser 0 avvik i innhold). Rekkefølgen internt i
`binds/`-filene spiller derfor ingen rolle for funksjon — kun for lesbarhet.

## Struktur

| Fil | Innhold |
|---|---|
| `globals.kdl` | `prefer-no-csd`, `hotkey-overlay`, `screenshot-path`, `animations` |
| `input.kdl` | tastatur, touchpad, mus, trackpoint |
| `outputs.kdl` | skjermoppsett |
| `layout.kdl` | gaps, focus-ring, border, shadow, struts, tabs |
| `gestures.kdl` | hot-corners |
| `startup.kdl` | `spawn-at-startup` / `environment` |
| `window-rules.kdl` | vindusregler |
| `binds/launchers.kdl` | overlay / launchere / apper |
| `binds/media-brightness.kdl` | tilgjengelighet / media / lysstyrke |
| `binds/session-power.kdl` | session / overview / quit / power |
| `binds/focus-nav.kdl` | fokus-navigasjon: kolonner / skjermer / workspaces |
| `binds/move-nav.kdl` | flytte kolonner/vinduer mellom kolonner/skjermer/workspaces |
| `binds/scroll-nav.kdl` | scroll-basert navigasjon |
| `binds/workspace-numbers.kdl` | workspaces etter nummer |
| `binds/column-nav.kdl` | navigasjon i kolonne / tabbing / consume-expel |
| `binds/sizing.kdl` | størrelse/layout-handlinger |
| `binds/floating.kdl` | floating-relaterte binds |
| `binds/screenshots.kdl` | skjermbilder |
| `main.kdl` | **inngangsporten** — `include`-er alle filene over, i rekkefølge |

## Bruk

### Midlertidig testing (endrer ingenting i din ekte config)

```fish
niri validate -c ~/dotfiles/niri/.config/niri/modules-mirror-binds/main.kdl
```

For å faktisk se den kjøre (nested niri i et vindu, inni din nåværende session):

```fish
niri -c ~/dotfiles/niri/.config/niri/modules-mirror-binds/main.kdl
```

Merk i nested-modus:
- `Mod` blir **Alt** i stedet for Super, for å unngå kollisjon med host-sesjonens binds.
- `Ctrl+Alt+Delete` er bundet til `quit` og bruker ikke `Mod` — raskeste vei ut av den nestede instansen.
- Niri live-reloader automatisk når du lagrer en av `binds/*.kdl`-filene, så du kan teste en enkelt keybind-gruppe om gangen i det nestede vinduet.

### Gjøre permanent

Anbefalt (minimal, reversibel):

```fish
cd ~/dotfiles/niri/.config/niri
cp config.kdl config.kdl.bak
echo 'include "modules-mirror-binds/main.kdl"' > config.kdl
niri validate -c config.kdl
```

Rull tilbake med `git checkout -- config.kdl` eller `mv config.kdl.bak config.kdl`.

Alternativ (fjerner indirection-nivået, flytter modulene opp som selve configen):

```fish
cd ~/dotfiles/niri/.config/niri
mv config.kdl config.kdl.bak
mv modules-mirror-binds/main.kdl config.kdl
mv modules-mirror-binds/*.kdl .
mv modules-mirror-binds/binds .
rmdir modules-mirror-binds
niri validate -c config.kdl
```

Merk: `binds/`-mappen havner da direkte under `.config/niri/binds/` — juster
`include`-stiene i `config.kdl` fra `binds/xxx.kdl` til samme (de er allerede
relative, så dette alternativet krever ingen stiendringer i selve
`config.kdl` — kun i mappestrukturen).
