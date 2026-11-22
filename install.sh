#!/usr/bin/env bash
set -euo pipefail

repository='https://github.com/eb-88/SSH-Manager.git'
checkout="$HOME/.local/share/ssh-manager"
launcher="$HOME/.local/bin/ssh-manager"

if [[ -e "$checkout" ]]; then
    if [[ ! -d "$checkout/.git" ]]; then
        printf 'Install directory exists but is not an SSH Manager Git checkout: %s\n' "$checkout" >&2
        exit 1
    fi
    printf 'SSH Manager is already installed. Update it? [y/N] ' >&2
    answer=''
    if ! IFS= read -r answer </dev/tty 2>/dev/null; then
        # A piped installer reads its source from stdin; never consume that stream as a response.
        if [[ -f ${BASH_SOURCE[0]} ]]; then IFS= read -r answer || answer=''; fi
    fi
    case ${answer,,} in
        y|yes|j|ja) git -C "$checkout" pull --ff-only ;;
        *) printf 'Existing installation was not changed.\n'; exit 0 ;;
    esac
else
    git clone --depth 1 "$repository" "$checkout"
fi

install -Dm755 "$checkout/ssh-manager.sh" "$launcher"
exec "$launcher"
