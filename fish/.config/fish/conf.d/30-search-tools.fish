# ==============================================================================
# Delt eksklusjonsliste for fd-baserte filsøk.
# Brukes av functions/ff.fish, functions/ffcd.fish og functions/fn.fish
# via den interne hjelpefunksjonen functions/__fd_excludes.fish.
#
# Én liste, ett sted å rette/utvide — tidligere lå denne listen kopiert inn i
# 3-4 abbreviations, og en av kopiene hadde fått en skrivefeil
# (dobbel "--exclude") som gjorde at søket alltid ga tomt resultat.
# ==============================================================================

set -g fish_search_excludes \
    .wine .vscode .git .cache .mozilla .local .npm .ssh .var .pki \
    .gitconfig gtkrc-2.0 .bash node_modules
