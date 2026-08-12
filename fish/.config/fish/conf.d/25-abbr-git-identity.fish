# ==============================================================================
# Bytt git-identitet (user.name/user.email) i det aktuelle repoet.
# Kjøres inne i et repo for å sette lokal (repo-spesifikk) identitet.
#
# Faktiske navn/e-poster ligger i en lokal, ikke-versjonert fil
# (25-abbr-git-identity.local.fish) som overstyrer placeholderne under.
# ==============================================================================

set -l local_identity (dirname (status --current-filename))/25-abbr-git-identity.local.fish
if test -f $local_identity
    source $local_identity
else
    abbr -a git-jobb 'git config user.name "CHANGE_ME"; git config user.email "jobb@example.com"'
    abbr -a git-priv 'git config user.name "CHANGE_ME"; git config user.email "privat@example.com"'
end
