#!/usr/bin/env bash

set -euo pipefail
SSH_MANAGER_LANG=de
source "$(dirname -- "${BASH_SOURCE[0]}")/../ssh-manager.sh"

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
store="$scratch/profiles"
remote="$scratch/remote"
mkdir -- "$remote"
calls="$scratch/calls"
screen="$scratch/screen"
auth=managed

ssh() {
    local command=${!#} log=''
    printf '%s\n' "$*" >> "$calls"
    while (($#)); do
        if [[ $1 == -E ]]; then log=$2; shift; fi
        shift
    done
    if [[ -n $log ]]; then
        local signer=managed
        if [[ $auth == other ]]; then signer=other; fi
        printf 'debug3: sign_and_send_pubkey: using publickey with ED25519 SHA256:%s\r\n' "$signer" > "$log"
        if [[ $auth != rejected ]]; then printf 'Authenticated to localhost (via proxy) using "publickey".\r\n' >> "$log"; fi
        return 7
    fi
    if [[ $command == 'cd ~ && sh -s -- '* ]]; then
        (cd -- "$remote" && sh -s -- "${command##* }")
    fi
}

ssh-keygen() {
    if [[ $1 == -l ]]; then
        printf '256 SHA256:managed test (ED25519)\n'
    else
        local key=${!#}
        printf 'private fixture\n' > "$key"
        printf 'ssh-ed25519 QUJD test\n' > "$key.pub"
    fi
}

run_menu() {
    printf '%s\n' "$@" | COLUMNS=24 main > "$screen" 2>&1
}

check() {
    "$@" >/dev/null || { printf 'Prüfung fehlgeschlagen (%s)\n' "$*" >&2; cat "$screen" >&2; exit 1; }
}

run_menu o n Web example.org deploy 0 2222 2 o n Stage ::1 ops '' 1 q
check grep -F '65535' "$screen"
check grep -F '[O]' "$screen"
check bash -c 'while IFS= read -r line; do ((${#line} <= 24)) || exit 1; done < "$1"' _ "$screen"
check jq -e -s 'length == 2 and any(.[]; .Name == "Web" and .Port == 2222)' "$store"/ziel-*.json

run_menu o s WEB 1 q
check grep -Fx -- '-p 2222 -l deploy -- example.org' "$calls"
run_menu 1 q
ready=("$store"/ziel-*.ed25519.ready)
key="${ready[0]%.ready}"
check grep -Fx 'ops@::1:22' "$key.ready"
check grep -Fx 'ssh-ed25519 QUJD' "$remote/.ssh/authorized_keys"
check grep -F 'SSH-Sitzung beendet.' "$screen"

run_menu o b 1 '' '' '' 2200 '' '' q
auth=other
before=$(wc -l < "$calls")
run_menu 1 n q
check test "$(wc -l < "$calls")" -eq "$((before + 1))"
check grep -Fx 'ops@::1:22' "$key.ready"

auth=rejected
restricted='command="echo \"two words\"",no-pty ssh-ed25519 QUJD test'
printf '%s\n' "$restricted" > "$remote/.ssh/authorized_keys"
run_menu 1 j q
check test "$(cat "$remote/.ssh/authorized_keys")" = "$restricted"
check grep -Fx 'ops@::1:22' "$key.ready"
auth=managed
run_menu 1 q
check grep -Fx 'ops@::1:2200' "$key.ready"

export_path="$scratch/SSH-Ziele.json"
run_menu o s web o e "$export_path" q
check jq -e '.Version == 1 and (.Targets | length == 2)
    and all(.Targets[]; keys == ["Login","Name","Port","Server","User"])' "$export_path"
before=$(sha256sum "$export_path")
run_menu o e "$export_path" q
check test "$(sha256sum "$export_path")" = "$before"

import_path="$scratch/import.json"
jq '.Targets[0] += {KeyId: "old-key", PrivateKey: "not a key", Password: "not a password"}' "$export_path" > "$import_path"
store="$scratch/restored"
run_menu o i "$import_path" o i "$export_path" q
check jq -es 'length == 2 and all(.[]; .KeyId != "old-key" and
    keys == ["KeyId","Login","Name","Port","Server","User"])' "$store"/ziel-*.json

jq '.Targets[0].Name = "Neue" | .Targets[1].Server = "-invalid"' "$export_path" > "$import_path"
if import_targets "$import_path" > "$screen" 2>&1; then exit 1; fi
check grep -F 'Eintrag 2' "$screen"
check jq -es 'length == 2' "$store"/ziel-*.json
run_menu o l 1 j q
check jq -es 'length == 1 and .[0].Name == "Web"' "$store"/ziel-*.json
# The new default renders English; switching languages persists without changing targets.
unset SSH_MANAGER_LANG
language=en
run_menu o g 2 o g 1 q
check grep -F 'Choose language' "$screen"
check grep -F 'Sprache wählen' "$screen"
check grep -Fx en "$store/language"
check jq -es 'length == 1 and .[0].Login == "Schlüssel"' "$store"/ziel-*.json
printf 'Linux-Tests bestanden.\n'
