# Struktur for fish-konfigen

Denne mappen er delt opp i moduler for å gjøre det enkelt å finne og endre
ting. Kort fortalt laster fish alt i `conf.d/` automatisk ved hver shell-start
(alfabetisk), deretter `config.fish`, og funksjoner i `functions/` lastes lazy
(bare når de faktisk kalles første gang).

```
fish/
├── config.fish              # Skal holdes tom/minimal - se nedenfor
├── fish_variables            # Fish-generert, ikke rediger manuelt
├── conf.d/
│   ├── 00-environment.fish        # EDITOR/VISUAL/MANPAGER, fish_greeting
│   ├── 05-ssh-agent.fish           # Auto-start ssh-agent + legg til nøkkel
│   ├── 06-zoxide.fish              # zoxide init (må kjøre før 10-aliases)
│   ├── 10-aliases.fish             # cd->z, cls, cat->bat
│   ├── 20-abbr-general.fish        # Git, dotfiles, ls/lt/mkdir/grep/npm, div.
│   ├── 25-abbr-git-identity.fish   # git-jobb / git-priv (bytt git-identitet)
│   ├── 30-search-tools.fish        # Delt exclude-liste for fd-søk (se under)
│   ├── 35-dotfiles-tools.fish      # $dotfiles_dir - fast peker til ~/dotfiles
│   ├── fish_frozen_key_bindings.fish  # Fish-generert migreringsfil, la stå
│   └── systemd-user-env.fish          # Importerer Wayland-env til systemd --user
└── functions/
    ├── __fd_excludes.fish   # Intern helper, bygger --exclude-flagg for fd
    ├── ff.fish              # Søk filnavn (fd+fzf)
    ├── fn.fish              # Søk filnavn, åpne treff i nvim
    ├── ffcd.fish            # Søk filnavn, cd til mappen filen ligger i
    ├── fcd.fish             # Søk mappenavn, cd inn i den
    ├── fc.fish              # Søk mappenavn, åpne i VS Code
    ├── dcd.fish             # Søk config-mappe i ~/dotfiles (uansett $PWD), cd inn
    ├── dcn.fish             # Søk config-fil i ~/dotfiles (uansett $PWD), åpne i nvim
    ├── mkcd.fish            # mkdir -p + cd i én kommando
    ├── rmcd.fish            # Slett nåværende mappe rekursivt, cd til foreldre
    ├── cdl.fish             # cd + ls -la
    ├── sc.fish              # ripgrep+fzf søk med forhåndsvisning i bat/nvim
    ├── reload.fish          # Restart fish-shell + reload kitty-farger
    └── rgf.fish             # ripgrep med gode defaults
```

## Hvorfor delt opp slik

Alt lå tidligere i én `config.fish` på over 100 linjer, med miljøvariabler,
aliaser, abbreviations og funksjoner blandet sammen. Det gjorde det vanskelig
å finne ting og førte til at samme kode (en lang exclude-liste for
filsøk) ble kopiert inn 3-4 steder - og en av kopiene fikk en skrivefeil som
gjorde søket permanent knekt uten at det var lett å se hvorfor.

## Retningslinjer for utvidelse

**Ny abbreviation (kort tekst som utvides synlig på kommandolinjen):**
Legg den i riktig fil under `conf.d/` etter tema (`20-abbr-general.fish`
for generelt, egen fil hvis det er en ny kategori). Abbreviations passer best
når du vil *se* hele kommandoen før den kjøres, eller når den bare er en
snarvei for et fast sett med flagg.

**Ny funksjon (kommando med logikk - if/for, flere linjer, delte variabler):**
Legg den i en egen fil i `functions/`, navngitt nøyaktig som funksjonen
(`functions/foo.fish` inneholder `function foo`). Fish autoloader disse - du
trenger ikke `source` dem noe sted. Bruk funksjon i stedet for abbr når
kommandoen skal gjøre noe (kalle andre kommandoer, bruke variabler, ha
betingelser) i stedet for å bare utvide til statisk tekst.

**Delte lister/variabler mellom flere funksjoner:**
Sett dem med `set -g` i en dedikert fil under `conf.d/` (se
`30-search-tools.fish`), og la funksjonene i `functions/` referere til
variabelen. Da finnes listen ett sted, ikke kopiert inn i hver funksjon.
Samme prinsipp brukes for `$dotfiles_dir` i `35-dotfiles-tools.fish`, som
lar `dcd`/`dcn` alltid søke i `~/dotfiles` via fd sitt `--search-path`-flagg
- helt uavhengig av hvilken mappe terminalen faktisk står i.

**Interne hjelpefunksjoner** (ikke tenkt kalt direkte av deg):
Prefiks med dobbel understrek, f.eks. `__fd_excludes.fish`. Dette er fish-
konvensjon og gjør at de ikke dukker opp som "vanlige" kommandoer i
tab-completion-listen på samme måte.

**Nummerering i `conf.d/`:**
Filene lastes alfabetisk. Prefikset (`00-`, `05-`, `10-` ...) styrer
lasterekkefølgen der det faktisk har betydning (f.eks. må zoxide initialiseres
før noe kan alias'es til `z`). Bruk hull i nummerrekken (05, 10, 20 osv., ikke
1, 2, 3) så det er plass til å sette inn noe mellom senere uten å måtte
renummerere alt.

**Test etter endring:**
```fish
fish -n conf.d/*.fish functions/*.fish config.fish   # syntaks-sjekk
reload                                                # laster alt på nytt i shellet
```
