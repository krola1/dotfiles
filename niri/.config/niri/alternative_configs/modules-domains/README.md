# modules-domains

## Tanken bak

Gruppert etter hva ting *styrer* i praksis, ikke etter hvilken KDL-blokktype
de tilfeldigvis tilhører i niris egen syntaks. Spørsmålet denne varianten
optimerer for er "hvor går jeg for å endre X", ikke "hvilken niri-seksjon er
X teknisk sett en del av".

`session.kdl` er et avvik fra en ren firedeling: `prefer-no-csd`,
`hotkey-overlay` og `screenshot-path` passet ikke naturlig inn under
machine/appearance/apps/rules/binds, så de fikk en egen liten fil i stedet
for å bli tvunget inn et sted de ikke hører hjemme.

## Struktur

| Fil | Innhold | Hvorfor gruppert slik |
|---|---|---|
| `session.kdl` | `prefer-no-csd`, `hotkey-overlay`, `screenshot-path` | Rene globale/session-innstillinger uten naturlig hjem andre steder |
| `machine.kdl` | `input` + alle `output`-blokker | Maskinvare — det som mest sannsynlig må endres først på en annen maskin |
| `appearance.kdl` | `animations` + `layout` + `gestures` | Visuell oppførsel/tuning, samlet ett sted |
| `apps.kdl` | `spawn-at-startup` + `environment` | Hva som starter opp og med hvilket miljø |
| `window-rules.kdl` | vindusregler | Uendret fra original |
| `binds.kdl` | hele keybind-blokken | Uendret fra original |
| `main.kdl` | **inngangsporten** — `include`-er de 6 filene over i riktig rekkefølge |

Innholdet er verifisert byte-for-byte likt originalen (normalisert diff = 0
linjer avvik) og validert med `niri validate`.

## Bruk

### Midlertidig testing (endrer ingenting i din ekte config)

```fish
niri validate -c ~/dotfiles/niri/.config/niri/modules-domains/main.kdl
```

For å faktisk se den kjøre (nested niri i et vindu, inni din nåværende session):

```fish
niri -c ~/dotfiles/niri/.config/niri/modules-domains/main.kdl
```

Merk i nested-modus:
- `Mod` blir **Alt** i stedet for Super, for å unngå kollisjon med host-sesjonens binds.
- `Ctrl+Alt+Delete` er bundet til `quit` og bruker ikke `Mod` — raskeste vei ut av den nestede instansen.
- Niri live-reloader automatisk når du lagrer en modulfil, så endringer i f.eks. `appearance.kdl` slår inn med en gang i det nestede vinduet.

### Gjøre permanent

Anbefalt (minimal, reversibel):

```fish
cd ~/dotfiles/niri/.config/niri
cp config.kdl config.kdl.bak
echo 'include "modules-domains/main.kdl"' > config.kdl
niri validate -c config.kdl
```

Rull tilbake med `git checkout -- config.kdl` eller `mv config.kdl.bak config.kdl`.

Alternativ (fjerner indirection-nivået, flytter modulene opp som selve configen):

```fish
cd ~/dotfiles/niri/.config/niri
mv config.kdl config.kdl.bak
mv modules-domains/main.kdl config.kdl
mv modules-domains/*.kdl .
rmdir modules-domains
niri validate -c config.kdl
```

Mer disruptiv — bruk kun når du er sikker på at domain-oppdelingen er den
du vil beholde permanent.
