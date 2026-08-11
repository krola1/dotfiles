# ==============================================================================
# SSH-agent: start agenten og legg til nøkkelen automatisk hvis den
# ikke allerede kjører (unngår å måtte kjøre ssh-add manuelt hver gang).
# ==============================================================================

if not set -q SSH_AUTH_SOCK
    eval (ssh-agent -c) >/dev/null
    ssh-add ~/.ssh/id_ed25519 >/dev/null
end
