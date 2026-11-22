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

records=$(list_records | jq -cs 'sort_by(.Name)')
check test "$(filter_records "$records" 'DEPLOY 2222' | jq -s length)" -eq 1
check test "$(filter_records "$records" 'managed STAGE' | jq -s length)" -eq 1
check test "$(filter_records "$records" 'OpenSSH stage' | jq -s length)" -eq 0
check test "$(filter_records "$records" '' | jq -s length)" -eq 2
run_menu o s 'DEPLOY 2222' 1 q
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

# Self-update tests: fake GitHub responses and validate installed file replacement.
manager_script="$scratch/install/ssh-manager.sh"
mkdir -p -- "${manager_script%/*}"
printf '#!/usr/bin/env bash\nmanager_version=0.3.7\n' > "$manager_script"
chmod 755 "$manager_script"
release_tag=v0.4.0
download_version=0.4.0
curl() {
    local output='' previous='' value
    if [[ " $* " == *'/releases/latest'* ]]; then
        printf '{"tag_name":"%s"}\n' "$release_tag"
        return 0
    fi
    for value in "$@"; do
        if [[ $previous == -o ]]; then output=$value; break; fi
        previous=$value
    done
    [[ -n $output ]] || return 1
    printf '#!/usr/bin/env bash\nmanager_version=%s\n' "$download_version" > "$output"
}
language=en
check_update <<< n > "$screen"
check grep -F 'available' "$screen"
check test "$available_update_version" = 0.4.0
show_targets 0 '' > "$screen"
check grep -F 'SSH-Manager · v0.3.7' "$screen"
check grep -F 'Outdated version! Update v0.4.0 available.' "$screen"
language=de
show_targets 0 '' > "$screen"
check grep -F 'Veraltete Version! Update v0.4.0 verfügbar.' "$screen"
language=en
check grep -Fx manager_version=0.3.7 "$manager_script"
download_version=0.5.0
check_update <<< y > "$screen"
check grep -F 'Update failed' "$screen"
check test "$available_update_version" = 0.4.0
check grep -Fx manager_version=0.3.7 "$manager_script"
download_version=0.4.0
check_update <<< y > "$screen"
check grep -F 'Installed v0.4.0' "$screen"
check test -z "$available_update_version"
check grep -Fx manager_version=0.4.0 "$manager_script"
release_tag=v0.3.7
check_update > "$screen"
check test ! -s "$screen"
check test -z "$available_update_version"
release_tag=v0.5.0
curl() { return 28; }
check_update > "$screen"
check test ! -s "$screen"
check test -z "$available_update_version"
check grep -Fx manager_version=0.4.0 "$manager_script"
printf 'Update-Tests bestanden.\n'
# Automatic updates are on by default, but a stored preference must suppress startup HTTP calls.
check auto_updates_enabled
run_menu o a q
check grep -Fx off "$store/auto-update"
if auto_updates_enabled; then exit 1; fi
request_log="$scratch/update-requests"
curl() {
    printf '%s\n' "$*" >> "$request_log"
    printf '{"tag_name":"%s"}\n' "$release_tag"
}
release_tag=v0.4.0
run_menu q
check test ! -f "$request_log"
run_menu o u n q
check grep -F 'v0.4.0 available.' "$screen"
check test "$(wc -l < "$request_log")" -eq 1
release_tag=v0.3.7
run_menu o u q
check grep -F 'No new version' "$screen"
check test "$(wc -l < "$request_log")" -eq 2
run_menu o a q
check grep -Fx on "$store/auto-update"
check auto_updates_enabled
release_tag=v0.4.0
run_menu n q
check test "$(wc -l < "$request_log")" -eq 3
check grep -F 'Outdated version!' "$screen"
printf 'Update preference tests passed.\n'

# Reproduce upgrading through the built-in self-updater, which does not rerun
# install.sh. The next normal launch must repair both missing shortcuts.
original_home=$HOME
original_manager_script=$manager_script
export HOME="$scratch/shortcut-home"
installed_launcher="$HOME/.local/bin/ssh-manager"
mkdir -p -- "${installed_launcher%/*}"
cp -- "$(dirname -- "${BASH_SOURCE[0]}")/../ssh-manager.sh" "$installed_launcher"
chmod 755 "$installed_launcher"
manager_script="$installed_launcher"
printf off > "$store/auto-update"
run_menu q
check test -L "$HOME/.local/bin/sshm"
check test -L "$HOME/.local/bin/SSHM"
check test "$(readlink -- "$HOME/.local/bin/sshm")" = ssh-manager
check test "$(readlink -- "$HOME/.local/bin/SSHM")" = ssh-manager
check test -x "$HOME/.local/bin/sshm"
check test -x "$HOME/.local/bin/SSHM"

# Subsequent launches preserve valid links and never clobber other commands.
rm -- "$HOME/.local/bin/sshm"
printf 'unrelated command\n' > "$HOME/.local/bin/sshm"
run_menu q
check grep -Fx 'unrelated command' "$HOME/.local/bin/sshm"
check grep -F 'already in use' "$screen"
check test -L "$HOME/.local/bin/SSHM"
rm -- "$HOME/.local/bin/sshm"
ln -s other-program "$HOME/.local/bin/sshm"
run_menu q
check test "$(readlink -- "$HOME/.local/bin/sshm")" = other-program

# Running a checkout or unrelated path must never modify the installed bin.
rm -- "$HOME/.local/bin/sshm"
manager_script="$scratch/install/ssh-manager.sh"
run_menu q
check test ! -e "$HOME/.local/bin/sshm"
manager_script="$HOME/.local/bin/SSHM"
run_menu q
check test "$(readlink -- "$HOME/.local/bin/sshm")" = ssh-manager

manager_script="$original_manager_script"
export HOME="$original_home"
printf 'Linux shortcut migration tests passed.\n'
