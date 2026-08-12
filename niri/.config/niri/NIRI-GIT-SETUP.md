# Niri-oppsett: skjulte workspaces + scratchpad

Denne maskinen kjører **ikke** Arch sin `niri`-pakke. Den kjører `niri-git`
bygget fra en draft-PR som legger til støtte for skjulte workspaces. Denne
filen er oppskriften for å gjenskape, oppdatere eller rulle tilbake det
oppsettet — les den før du rører niri-installasjonen på denne maskinen.

## Kort oppsummert

Kompositoren er bygget fra draft-PR
[niri-wm/niri#2997](https://github.com/niri-wm/niri/pull/2997), branch
`hidden-workspaces`. Den legger til `hidden true` på workspaces og
IPC-kommandoen `workspaces-with-hidden`. Uten denne PR-en feiler
config-parsingen på `hidden true` i `.config/niri/modules-mirror/scratchpad.kdl`.

Sist verifisert installert versjon: `niri-git 26.04.r52.g3508510-1`
(erstattet standard `niri 26.04-1`).

## Hvorfor

Scratchpad-oppsettet (`.config/niri/modules-mirror/scratchpad.kdl`) flytter
vinduer til et workspace kalt `stash`. Uten `hidden true` dukker `stash` opp
i overview og i bar/workspace-widgets. PR-en gjør at workspacet fungerer helt
normalt, men ikke annonseres til event-strømmen.

## Komponenter og hvor de faktisk bor

| Hva | Hvor | Kilde |
|---|---|---|
| Patchet niri (kompilert til pacman-pakken `niri-git`) | `~/src/niri`, branch `hidden-workspaces` | fork/fetch av niri-wm/niri PR #2997 |
| PKGBUILD | `~/src/niri-git` | AUR `niri-git`, med lokal `source=`-endring (**ikke** committet til AUR) |
| `niri-scratchpad` (daemon/CLI) | binær i `/usr/local/bin/niri-scratchpad` | `~/niri-scratchpad-rs`, branch `hidden-workspaces`, fork av github.com/argosnothing/niri-scratchpad-rs |
| `niri-stash-toggle` | binær i `/usr/local/bin/niri-stash-toggle` | dette repoet: `.config/niri/scripts/niri-stash-toggle` |
| `niri-stash-leave` | binær i `/usr/local/bin/niri-stash-leave` | dette repoet: `.config/niri/scripts/niri-stash-leave` |
| `niri-stash-nav` | binær i `/usr/local/bin/niri-stash-nav` | dette repoet: `.config/niri/scripts/niri-stash-nav` |
| Config for stash-workspace + autostart | dette repoet | `.config/niri/modules-mirror/scratchpad.kdl` |

`niri-scratchpad` er bygget fra branchen `hidden-workspaces`, som vendorer en
patchet `niri-ipc` 25.11 som path-dependency — den må matche kompositorens
IPC-versjon. `main`-branchen i den forken gjør det ikke.

Binærer havner i `/usr/local/bin` fordi niri arver PATH fra
systemd-user-manageren, ikke fra `config.fish`. `~/.local/bin` er **ikke** i
den PATH-en, så programmer der ville feilet stille når de spawnes fra et
keybind eller `spawn-at-startup`.

**Viktig, lett å glemme:** binærer i `/usr/local/bin` oppdateres ALDRI
automatisk når du endrer et script i dette repoet. Etter en endring i
`.config/niri/scripts/niri-stash-toggle`, `niri-stash-leave` eller
`niri-stash-nav` må du reinstallere manuelt:

```bash
sudo install -Dm755 ~/dotfiles/niri/.config/niri/scripts/niri-stash-toggle /usr/local/bin/niri-stash-toggle
sudo install -Dm755 ~/dotfiles/niri/.config/niri/scripts/niri-stash-leave /usr/local/bin/niri-stash-leave
sudo install -Dm755 ~/dotfiles/niri/.config/niri/scripts/niri-stash-nav /usr/local/bin/niri-stash-nav
```

## Gjenskape hele oppsettet fra bunnen (f.eks. etter en reinstall)

PR-refs kan ikke hentes direkte av `makepkg`, derfor omveien via lokalt klon:

```bash
mkdir -p ~/src && cd ~/src
git clone https://github.com/niri-wm/niri.git
cd niri
git fetch origin pull/2997/head:hidden-workspaces
git checkout hidden-workspaces
```

```bash
cd ~/src
git clone https://aur.archlinux.org/niri-git.git
cd niri-git
```

Rediger `PKGBUILD` og bytt `source=`-linjen til:

```
source=("git+file:///home/beastboy/src/niri#branch=hidden-workspaces")
```

Deretter:

```bash
makepkg -si
```

Klon og bygg scratchpad-verktøyet:

```bash
cd ~
git clone https://github.com/argosnothing/niri-scratchpad-rs.git
cd niri-scratchpad-rs
git checkout hidden-workspaces
cargo build --release
sudo install -Dm755 target/release/niri-scratchpad /usr/local/bin/niri-scratchpad
sudo install -Dm755 ~/dotfiles/niri/.config/niri/scripts/niri-stash-toggle /usr/local/bin/niri-stash-toggle
```

**Risiko ved dette:** PR #2997 er en draft og kan bli rebaset eller lukket.
Hvis `git fetch origin pull/2997/head` ikke lenger gir commiten
`3508510f` ("added hidden logic to windows"), er PR-en enten rebaset (fetch
på nytt og sjekk om oppførselen fortsatt stemmer) eller borte for godt (finn
en fork/branch med samme endring, eller dropp `hidden true` og fjern den
seksjonen fra `scratchpad.kdl`).

## Oppdatere når PR-en rebases

Fetchen må skje fra en annen branch enn den utsjekkede — git nekter å skrive
til en utsjekket branch.

```bash
cd ~/src/niri && git checkout main
git fetch origin pull/2997/head:hidden-workspaces --force
git checkout hidden-workspaces
cd ~/src/niri-git && makepkg -si
```

Deretter **full ut- og innlogging**. Kompositoren kan ikke bytte seg selv ut
mens sesjonen kjører. Vanlige config-endringer krever bare lagring;
`spawn-at-startup` krever relogin eller manuell start.

Bytter `niri-ipc` seg i PR-en, må `niri-scratchpad` bygges på nytt også, og
gammel daemon drepes: `pkill -f "niri-scratchpad daemon"`.

## Rulle tilbake til standard niri

```bash
sudo pacman -U /var/cache/pacman/pkg/niri-26.04-1-x86_64.pkg.tar.zst
```

Fjern deretter `hidden true` fra `stash`-blokka i
`.config/niri/modules-mirror/scratchpad.kdl`, ellers nekter niri å starte
(parse-feil på ukjent nøkkel).

Ved feilet innlogging: bytt til TTY med Ctrl+Alt+F2 og fiks derfra.

## Kjent risiko

- Draft-PR: kan bli rebaset eller slutte å kompilere uten forvarsel.
- Ingen sikkerhetsoppdateringer fra Arch så lenge `niri-git` er installert.
- `pacman -Syu` rører ikke `niri-git`, men oppdaterer den heller ikke.
- Maskinen brukes til undervisning — ikke bygg på nytt kvelden før en økt.
