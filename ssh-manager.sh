#!/usr/bin/env bash

set -o pipefail
umask 077

store="$HOME/.ssh/ssh-manager"
width=80
probe_options=(-T -o ControlPath=none -o ClearAllForwardings=yes -o PermitLocalCommand=no
    -o ForwardAgent=no -o ForwardX11=no -o RemoteCommand=none)

profile_schema='
def valid($pattern): if type == "string" then test($pattern) else false end;
def profile:
    if type != "object" then error("Ungültiges Profil.")
    elif (.Name | valid("\\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\\z") | not) then error("Ungültiger Kurzname.")
    elif (.Server | valid("\\A[A-Za-z0-9:][A-Za-z0-9._:-]*\\z") | not) then error("Ungültiger Host.")
    elif (.User | valid("\\A[A-Za-z0-9_][A-Za-z0-9._@-]*\\z") | not) then error("Ungültiger Benutzer.")
    elif (.Port | if type == "number" or type == "string" then
            tostring | if test("\\A[0-9]{1,5}\\z") then tonumber | . >= 1 and . <= 65535 else false end
        else false end | not) then error("Ungültiger Port.")
    elif (.Login | valid("(?i)\\A(Passwort|Schlüssel)\\z") | not) then error("Ungültige Anmeldeart.")
    else {Name, Server, User, Port: (.Port | tonumber),
        Login: (if (.Login | ascii_downcase) == "passwort" then "Passwort" else "Schlüssel" end)}
    end;
'

fail() {
    printf 'Fehler · %s\n' "$*" >&2
    return 1
}

with_lock() (
    shift
    flock -n 9 || { fail 'Der Speicher ist gerade in Benutzung. Bitte erneut versuchen.'; return 1; }
    "$@"
) 9>>"$1"

write_file() {
    local path=$1 data=$2 mode=$3 temp status=0
    temp=$(mktemp -- "${path%/*}/.ssh-manager.XXXXXXXX") || return 1
    if ! printf '%s' "$data" > "$temp"; then
        status=1
    elif [[ $mode == replace ]]; then
        mv -Tf -- "$temp" "$path" || status=$?
    else
        ln -T -- "$temp" "$path" || status=$?
    fi
    rm -f -- "$temp"
    return "$status"
}

load_record() {
    local path=$1 snapshot
    [[ -f $path && ! -L $path ]] || return 1
    snapshot=$(sha256sum < "$path") || return 1
    jq -ces --arg path "$path" --arg filename "${path##*/}" --arg snapshot "${snapshot%% *}" "$profile_schema"'
        if length != 1 then error("Ungültige Profildatei.") else .[0] end
        | . as $source | profile as $profile
        | $profile + {
            KeyId: (if $source.KeyId == null then
                ($profile.Name | ascii_downcase) as $name
                | if ($filename | ascii_downcase) == ("ziel-" + $name + ".json") then $name
                    else error("Kurzname passt nicht zur Datei.") end
                elif ($source.KeyId | valid("\\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\\z")) then $source.KeyId
                else error("Ungültige Schlüssel-ID.") end),
            Path: $path, Snapshot: $snapshot
        }' "$path"
}

list_records() {
    local path record
    for path in "$store"/ziel-*.json; do
        [[ -f $path ]] || continue
        if record=$(load_record "$path" 2>/dev/null); then
            printf '%s\n' "$record"
        else
            printf 'Profil %q konnte nicht gelesen werden.\n' "${path##*/}" >&2
        fi
    done
}

write_record() {
    local profile=$1 path=${2:-} key_id=${3:-} document mode=replace
    if [[ -z $key_id ]]; then
        IFS= read -r key_id < /proc/sys/kernel/random/uuid || return 1
        key_id=${key_id//-/}
    fi
    if [[ -z $path ]]; then
        path="$store/ziel-$key_id.json"
        mode=create
    fi
    document=$(jq --arg key_id "$key_id" '. + {KeyId: $key_id}' <<< "$profile") || return 1
    write_file "$path" "$document" "$mode"
}

save_target() {
    local profile=$1 original=$2 keep_key=$3 name path='' key_id='' current duplicate
    if [[ -n $original ]]; then
        path=$(jq -r '.Path' <<< "$original") || return 1
        if ! current=$(load_record "$path" 2>/dev/null) || [[ $current != "$original" ]]; then
            fail 'Das Ziel wurde inzwischen geändert oder gelöscht. Bitte erneut auswählen.'
            return 1
        fi
        if [[ $keep_key == yes ]]; then key_id=$(jq -r '.KeyId' <<< "$original") || return 1; fi
    fi
    name=$(jq -r '.Name | ascii_downcase' <<< "$profile") || return 1
    duplicate=$(list_records | jq -s --arg name "$name" --arg path "$path" \
        'any(.[]; (.Name | ascii_downcase) == $name and .Path != $path)') || return 1
    if [[ $duplicate == true ]]; then
        fail 'Dieser Kurzname ist bereits vergeben.'
        return 1
    fi
    write_record "$profile" "$path" "$key_id"
}

remove_target() {
    local original=$1 path current
    path=$(jq -r '.Path' <<< "$original") || return 1
    if ! current=$(load_record "$path" 2>/dev/null) || [[ $current != "$original" ]]; then
        fail 'Das Ziel wurde inzwischen geändert oder gelöscht. Bitte erneut auswählen.'
        return 1
    fi
    rm -- "$path"
}

export_targets() {
    local path=$1 document
    if [[ -e $path || -L $path ]]; then
        fail 'Die Datei existiert bereits. Bitte einen anderen Dateinamen wählen.'
        return 1
    fi
    document=$(list_records | jq -s "$profile_schema"'{
        Version: 1, Targets: (map(profile) | sort_by(.Name | ascii_downcase))
    }') || return 1
    write_file "$path" "$document" create && jq '.Targets | length' <<< "$document"
}

import_targets() {
    local path=$1 profiles
    profiles=$(jq -ces "$profile_schema"'
        if length == 1 and (.[0] | type) == "object" and .[0].Version == 1 and (.[0].Targets | type) == "array" then
            .[0].Targets | to_entries | map(.key as $index | try (.value | profile)
                catch error("Eintrag \($index + 1) · \(.)"))
        else error("Bitte eine gültige SSH-Manager-Exportdatei (Version 1) wählen.") end
    ' "$path") || return 1
    with_lock "$store/ziele.lock" import_profiles "$profiles"
}

import_profiles() {
    local profiles=$1 existing rows name profile added=0 skipped=0
    local -A known=()
    existing=$(list_records | jq -rs '.[] | .Name | ascii_downcase') || return 1
    while IFS= read -r name; do
        if [[ -n $name ]]; then known[$name]=1; fi
    done <<< "$existing"
    rows=$(jq -c '.[]' <<< "$profiles") || return 1
    while IFS= read -r profile; do
        [[ -n $profile ]] || continue
        name=$(jq -r '.Name | ascii_downcase' <<< "$profile") || return 1
        if [[ ${known[$name]+yes} ]]; then
            ((skipped += 1))
        else
            write_record "$profile" || { fail "Import nach $added gespeicherten Zielen abgebrochen."; return 1; }
            known[$name]=1
            ((added += 1))
        fi
    done <<< "$rows"
    printf '%s übernommen, %s übersprungen\n' "$added" "$skipped"
}

verify_key() {
    local key=$1 fingerprint expected log status=0
    shift
    fingerprint=$(ssh-keygen -l -E sha256 -f "$key") || return 1
    read -r _ expected _ <<< "$fingerprint"
    [[ $expected == SHA256:* ]] || return 1
    log=$(mktemp) || return 1
    # Authentifizierung und Status des Remote-Befehls können auseinanderfallen.
    ssh -n -vvv -E "$log" "${probe_options[@]}" -o FingerprintHash=sha256 \
        -o PreferredAuthentications=publickey -o IdentitiesOnly=yes -i "$key" "$@" 'exit 0' || true
    awk -v expected="$expected" '
        { sub(/\r$/, "") }
        /^debug3: sign_and_send_pubkey: (using [^ ]+ with )?[^ ]+ SHA256:[^ ]+$/ { signer = $NF }
        /^Authenticated to .+ using "publickey"\.$/ || /^debug1: Authentication succeeded \(publickey\)\.$/ {
            accepted = signer == expected
            exit
        }
        END { exit !accepted }
    ' "$log" || status=$?
    rm -f -- "$log"
    return "$status"
}

install_key() {
    local key=$1 endpoint=$2 public blob
    shift 2
    local -a password=("${probe_options[@]}" -o PreferredAuthentications=password,keyboard-interactive)
    [[ -f $key.ready && $(< "$key.ready") == "$endpoint" ]] && return 0
    if [[ -f $key ]]; then
        menu_text 'Vorhandenen Schlüssel prüfen …'
        if verify_key "$key" "$@"; then
            write_file "$key.ready" "$endpoint" replace
            return
        fi
        menu_text 'Ein neuer Eintrag kann bestehende Schlüsselbeschränkungen umgehen.'
        ask 'Schlüssel erneut freigeben? [j/N]' || return 1
        [[ ${REPLY,,} == j || ${REPLY,,} == ja ]] || return 1
    fi
    menu_text 'Passwortanmeldung prüfen … Beim Erstkontakt den Host-Fingerabdruck abgleichen.'
    ssh -n "${password[@]}" "$@" 'exit 0' || { fail 'Passwortanmeldung fehlgeschlagen.'; return 1; }
    if [[ ! -f $key ]]; then
        [[ ! -e $key.pub && ! -L $key && ! -L $key.pub ]] || { fail 'Das Schlüsselpaar ist unvollständig.'; return 1; }
        ssh-keygen -t ed25519 -f "$key" || return 1
    fi
    public=$(cat -- "$key.pub") || return 1
    local public_pattern='^ssh-ed25519 ([A-Za-z0-9+/]+={0,2})( [^[:cntrl:]]*)?$'
    [[ $public =~ $public_pattern ]] || { fail 'Ungültiger öffentlicher Schlüssel.'; return 1; }
    blob=${BASH_REMATCH[1]}
    menu_text 'Schlüssel übertragen … Serverpasswort erneut eingeben.'
    ssh "${password[@]}" "$@" "cd ~ && sh -s -- $blob" <<'REMOTE' || return 1
set -eu
umask 077
mkdir -p .ssh
chmod 700 .ssh
cd .ssh
touch authorized_keys
chmod 600 authorized_keys
key=$1
set -- authorized_keys
if [ -f authorized_keys2 ]; then set -- "$@" authorized_keys2; fi
present=$(awk -v key="$key" '
    /^[[:space:]]*#/ { next }
    {
        gsub(/\\"/, "")
        gsub(/"[^"]*"/, "")
        sub(/[[:space:]]+$/, "")
        if (($1 == "ssh-ed25519" && $2 == key) || ($2 == "ssh-ed25519" && $3 == key)) found = 1
    }
    END { print found + 0 }
' "$@")
if [ "$present" = 0 ]; then
    printf '\nssh-ed25519 %s\n' "$key" >> authorized_keys
fi
REMOTE
    menu_text 'Anmeldung mit dem Schlüssel prüfen …'
    verify_key "$key" "$@" || { fail 'Schlüsselanmeldung fehlgeschlagen. Beim nächsten Versuch wird derselbe Schlüssel verwendet.'; return 1; }
    write_file "$key.ready" "$endpoint" replace
}

connect_target() {
    local fields name server user port login key_id key endpoint status
    fields=$(target_fields "$1") || return 1
    IFS=$'\t' read -r name server user port login key_id <<< "$fields"
    local -a connection=(-p "$port" -l "$user" -- "$server") identity=()
    printf '\n'
    menu_text "Verbinde · $name"
    menu_text "$(address "$server" "$user" "$port")"
    if [[ $login == Passwort ]]; then
        key="$store/ziel-$key_id.ed25519"
        endpoint="$user@${server,,}:$port"
        if [[ ! -f $key.ready || $(< "$key.ready") != "$endpoint" ]]; then
            with_lock "$key.lock" install_key "$key" "$endpoint" "${connection[@]}" || return 1
        fi
        [[ -f $key ]] || { fail 'Privater Schlüssel fehlt.'; return 1; }
        identity=(-o PreferredAuthentications=publickey -o IdentitiesOnly=yes -i "$key")
    fi
    if ssh "${identity[@]}" "${connection[@]}"; then
        menu_text 'SSH-Sitzung beendet.'
    else
        status=$?
        menu_text "SSH beendet (Status $status). Details stehen in der SSH-Ausgabe."
    fi
}

get_width() {
    local columns=${COLUMNS:-80} size
    if [[ -t 0 && -t 1 ]] && size=$(stty size 2>/dev/null); then columns=${size##* }; fi
    [[ $columns =~ ^[0-9]{1,4}$ ]] || columns=80
    width=$((10#$columns))
    if ((width < 4)); then width=80; fi
    if ((width > 104)); then width=104; fi
}

menu_text() {
    local text=$1 part
    while ((${#text} > width)); do
        part=${text:0:width}
        if [[ ${text:width:1} != ' ' && $part == *' '* && ${part% *} == *[![:space:]]* ]]; then
            part=${part% *}
        fi
        printf '%s\n' "$part"
        text=${text:${#part}}
        text=${text#"${text%%[![:space:]]*}"}
    done
    printf '%s\n' "$text"
}

trim() {
    REPLY=${REPLY#"${REPLY%%[![:space:]]*}"}
    REPLY=${REPLY%"${REPLY##*[![:space:]]}"}
}

ask() {
    local prompt=$1
    if ((${#prompt} + 2 > width)); then menu_text "$prompt"; prompt='>'; fi
    printf '%s: ' "$prompt"
    IFS= read -r REPLY || return 1
    if [[ ! -t 0 ]]; then printf '\n'; fi
    trim
}

read_field() {
    local prompt=$1 default=$2 pattern=$3 hint=$4 LC_ALL=C
    if [[ -n $default ]]; then prompt+=" [$default]"; fi
    while ask "$prompt"; do
        [[ $REPLY != '!' ]] || return 1
        REPLY=${REPLY:-$default}
        if [[ $REPLY =~ $pattern ]]; then
            if [[ $1 != Port ]] || ((10#$REPLY >= 1 && 10#$REPLY <= 65535)); then return 0; fi
        fi
        menu_text "$hint"
    done
    return 1
}

target_fields() {
    jq -r '[.Name, .Server, .User, .Port, .Login, .KeyId] | @tsv' <<< "$1"
}

address() {
    local server=$1
    if [[ $server == *:* ]]; then server="[$server]"; fi
    printf '%s@%s:%s' "$2" "$server" "$3"
}

edit_target() {
    local original=${1:-} old_name='' old_server='' old_user='' old_port=22 old_login=Passwort
    local fields name server user port login default_login=1 keep_key=no profile
    printf '\n'
    if [[ -n $original ]]; then
        fields=$(target_fields "$original") || return 1
        IFS=$'\t' read -r old_name old_server old_user old_port old_login _ <<< "$fields"
        menu_text "Ziel bearbeiten · $old_name"
    else
        menu_text 'Neues SSH-Ziel'
    fi
    menu_text 'Enter übernimmt den Wert in [Klammern]. ! bricht ab.'
    read_field Kurzname "$old_name" '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' 'Erlaubt sind 1–64 Zeichen: Buchstaben, Zahlen, Punkt, _ und -.' || return 0
    name=$REPLY
    read_field 'Host oder IP' "$old_server" '^[A-Za-z0-9:][A-Za-z0-9._:-]*$' 'Bitte Hostname oder IP ohne Klammern eingeben.' || return 0
    server=$REPLY
    read_field SSH-Benutzer "$old_user" '^[A-Za-z0-9_][A-Za-z0-9._@-]*$' 'Bitte einen gültigen SSH-Benutzernamen eingeben.' || return 0
    user=$REPLY
    read_field Port "$old_port" '^[0-9]{1,5}$' 'Bitte einen Port zwischen 1 und 65535 eingeben.' || return 0
    port=$((10#$REPLY))
    menu_text '1  Schlüssel per Serverpasswort einrichten'
    menu_text '2  Bestehende OpenSSH-Konfiguration nutzen'
    if [[ $old_login == Schlüssel ]]; then default_login=2; fi
    read_field Anmeldung "$default_login" '^[12]$' 'Bitte 1 oder 2 wählen.' || return 0
    login=Passwort
    if [[ $REPLY == 2 ]]; then login=Schlüssel; fi
    if [[ -n $original && ${server,,} == "${old_server,,}" && $user == "$old_user" ]]; then
        keep_key=yes
        if [[ $login == Passwort && $port != "$old_port" ]]; then
            read_field 'Schlüssel am neuen Port behalten? (j/n)' j '^([jJ]([aA])?|[nN]([eE][iI][nN])?)$' 'Bitte j oder n wählen.' || return 0
            if [[ ${REPLY,,} == n || ${REPLY,,} == nein ]]; then keep_key=no; fi
        fi
    fi
    profile=$(jq -cn --arg Name "$name" --arg Server "$server" --arg User "$user" \
        --argjson Port "$port" --arg Login "$login" '{Name: $Name, Server: $Server, User: $User, Port: $Port, Login: $Login}') || return 1
    with_lock "$store/ziele.lock" save_target "$profile" "$original" "$keep_key" &&
        menu_text "Ziel '$name' gespeichert."
}

show_targets() {
    local total=$1 filter=$2 row fields name server user port login endpoint label line number=0
    shift 2
    printf '\n'
    menu_text SSH-Manager
    if [[ -n $filter ]]; then menu_text "Suche „$filter“ · $# von $total"; else menu_text "SSH-Ziele ($total)"; fi
    printf '\n'
    for row in "$@"; do
        ((number += 1))
        fields=$(target_fields "$row") || return 1
        IFS=$'\t' read -r name server user port login _ <<< "$fields"
        endpoint=$(address "$server" "$user" "$port")
        label=OpenSSH
        if [[ $login == Passwort ]]; then label=Verwaltet; fi
        line="$number  $name  ·  $endpoint  ·  $label"
        if ((width >= 68 && ${#line} <= width)); then
            printf '%s\n' "$line"
        else
            menu_text "$number  $name"
            if ((${#endpoint} + ${#label} + 5 <= width)); then
                menu_text "  $endpoint · $label"
            elif ((${#endpoint} + 2 <= width)); then
                menu_text "  $endpoint"
                menu_text "  $label"
            else
                menu_text "  $server"
                menu_text "  $user · Port $port"
                menu_text "  $label"
            fi
        fi
    done
    if (($#)); then
        printf '\n'
        menu_text '[Nr] Verbinden   [O] Optionen   [Q] Beenden'
    else
        if [[ -n $filter ]]; then menu_text 'Keine Treffer. Suche unter Optionen ändern.'; else menu_text 'Noch keine Ziele. Unter Optionen kannst du Ziele anlegen oder importieren.'; fi
        printf '\n'
        menu_text '[O] Optionen   [Q] Beenden'
    fi
}

read_option() {
    printf '\n'
    menu_text Optionen
    menu_text '[N] Neu   [B] Bearbeiten   [L] Löschen'
    menu_text '[S] Suchen   [I] Import   [E] Export'
    menu_text '[Enter] Zurück'
    while ask Option; do
        case ${REPLY,,} in ''|n|b|l|s|i|e) return 0 ;; esac
        menu_text 'Bitte eine angezeigte Option wählen.'
    done
    return 1
}

transfer_targets() {
    local action=$1 path count
    if [[ $action == i ]]; then
        menu_text 'Import · Gleichnamige Ziele werden übersprungen.'
    else
        menu_text 'Export · Alle Ziele ohne SSH-Schlüssel.'
    fi
    ask 'Pfad zur JSON-Datei (Enter zurück)' || return 0
    [[ -n $REPLY ]] || return 0
    path=$REPLY
    if [[ $path == \"*\" ]]; then path=${path:1:-1}; fi
    if [[ $path == '~/'* ]]; then path="$HOME/${path:2}"; fi
    if [[ $path != /* ]]; then path="$PWD/$path"; fi
    if [[ $action == i ]]; then
        count=$(import_targets "$path") && menu_text "Import abgeschlossen · $count."
    else
        count=$(export_targets "$path") && menu_text "Export abgeschlossen · $count gespeichert."
    fi
}

start_manager() {
    local records rows total filter='' action selection index target name
    local -a visible=()
    while true; do
        get_width
        records=$(list_records | jq -cs 'sort_by(.Name | ascii_downcase)') || return 1
        total=$(jq length <<< "$records") || return 1
        rows=$(jq -c --arg filter "$filter" '
            .[] | select(([.Name, (.User + "@" + .Server + ":" + (.Port | tostring))] | join(" ") | ascii_downcase)
                | contains($filter | ascii_downcase))' <<< "$records") || return 1
        visible=()
        if [[ -n $rows ]]; then mapfile -t visible <<< "$rows"; fi
        show_targets "$total" "$filter" "${visible[@]}" || return 1
        ask Auswahl || return 0
        action=''
        selection=$REPLY
        case ${REPLY,,} in
            q) return 0 ;;
            '') continue ;;
            o)
                read_option || return 0
                action=${REPLY,,}
                case $action in
                    '') continue ;;
                    n) edit_target || true; continue ;;
                    s)
                        ask 'Suche (Enter setzt zurück)' || return 0
                        filter=${REPLY//[[:cntrl:]]/}
                        continue ;;
                    i|e) transfer_targets "$action" || true; continue ;;
                esac
                if ((! ${#visible[@]})); then menu_text 'Keine Ziele zur Auswahl.'; continue; fi
                if [[ $action == b ]]; then
                    ask 'Bearbeiten · Nr (Enter zurück)' || return 0
                else
                    ask 'Löschen · Nr (Enter zurück)' || return 0
                fi
                selection=$REPLY
                [[ -n $selection ]] || continue ;;
        esac
        if [[ ! $selection =~ ^[0-9]{1,9}$ ]] || ((10#$selection < 1 || 10#$selection > ${#visible[@]})); then
            menu_text 'Bitte eine angezeigte Zielnummer eingeben.'
            continue
        fi
        index=$((10#$selection - 1))
        target=${visible[index]}
        case $action in
            b) edit_target "$target" || true ;;
            l)
                name=$(jq -r '.Name' <<< "$target") || continue
                menu_text "Ziel löschen · $name"
                menu_text 'Lokale Schlüssel und Serverfreigaben bleiben erhalten.'
                ask 'Ziel löschen? [j/N]' || return 0
                if [[ ${REPLY,,} == j || ${REPLY,,} == ja ]]; then
                    if with_lock "$store/ziele.lock" remove_target "$target"; then menu_text "Ziel '$name' gelöscht."; fi
                fi ;;
            *) connect_target "$target" || menu_text 'Keine SSH-Sitzung geöffnet.' ;;
        esac
    done
}

main() {
    local dependency
    for dependency in jq ssh ssh-keygen flock; do
        command -v "$dependency" >/dev/null || { fail "Benötigter Befehl fehlt ($dependency)."; return 1; }
    done
    mkdir -p -- "$store" && start_manager
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
