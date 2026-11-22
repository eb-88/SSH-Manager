#!/usr/bin/env bash

set -o pipefail
umask 077

store="$HOME/.ssh/ssh-manager"
width=80

# Must match the latest published stable release when tagging a new version.
manager_version=0.3.4
available_update_version=''
manager_script=${BASH_SOURCE[0]}

check_update() {
    local manual=${1:-} release tag version latest answer dest temporary url
    available_update_version=''
    release=$(curl -fsSL --max-time 5 -H 'Accept: application/vnd.github+json' -H 'User-Agent: SSH-Manager' 'https://api.github.com/repos/eb-88/SSH-Manager/releases/latest' 2>/dev/null) || { [[ $manual != manual ]] || menu_text 'Updateprüfung fehlgeschlagen.'; return 0; }
    tag=$(jq -r '.tag_name // ""' <<< "$release" 2>/dev/null) || { [[ $manual != manual ]] || menu_text 'Updateprüfung fehlgeschlagen.'; return 0; }
    [[ $tag =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || { [[ $manual != manual ]] || menu_text 'Updateprüfung fehlgeschlagen.'; return 0; }
    version=${tag#v}
    latest=$(printf '%s\n%s\n' "$manager_version" "$version" | sort -V | tail -n 1)
    [[ $latest == "$version" && $version != "$manager_version" ]] || { [[ $manual != manual ]] || menu_text 'Keine neue Version verfügbar.'; return 0; }
    available_update_version=$version
    if [[ $language == de ]]; then
        ask "Version v$version verfügbar (installiert: v$manager_version). Jetzt installieren? [j/N]" || return 0
    else
        ask "Version v$version available (installed: v$manager_version). Install now? [y/N]" || return 0
    fi
    answer=${REPLY,,}
    [[ $answer == y || $answer == yes || $answer == j || $answer == ja ]] || return 0
    dest=$manager_script
    [[ $dest == /* ]] || dest="$PWD/$dest"
    temporary=$(mktemp -- "${dest%/*}/.ssh-manager-update.XXXXXXXX") || return 0
    url="https://raw.githubusercontent.com/eb-88/SSH-Manager/$tag/ssh-manager.sh"
    if curl -fsSL --max-time 15 -o "$temporary" "$url" 2>/dev/null &&
        grep -Fxq "manager_version=$version" "$temporary" &&
        bash -n "$temporary" &&
        chmod --reference="$dest" "$temporary" &&
        mv -f -- "$temporary" "$dest"; then
        available_update_version=''
        if [[ $language == de ]]; then
            menu_text "Version v$version installiert. Beim nächsten Start aktiv."
        else
            menu_text "Installed v$version. It will run on the next launch."
        fi
    else
        if [[ $language == de ]]; then
            menu_text 'Update fehlgeschlagen. Die bisherige Version bleibt erhalten.'
        else
            menu_text 'Update failed. The existing version was kept.'
        fi
    fi
    rm -f -- "$temporary"
}


# Display-only localization. Saved profile values stay compatible.
language=en
translation_from=(
    'Der Kurzname braucht 1–64 Zeichen und beginnt mit einem Buchstaben oder einer Zahl. Erlaubt sind A–Z, 0–9, Punkt, Unterstrich und Bindestrich.'
    'Die Anmeldung mit dem bisherigen Schlüssel konnte nicht bestätigt werden. Ein neuer Eintrag kann bestehende Schlüsselbeschränkungen umgehen.'
    'Anmeldung mit dem vorgesehenen Schlüssel fehlgeschlagen. Beim nächsten Versuch wird derselbe Schlüssel verwendet.'
    'Schlüsselanmeldung fehlgeschlagen. Beim nächsten Versuch wird derselbe Schlüssel verwendet.'
    'Dafür einen Verweis im PowerShell-Modulverzeichnis deines Benutzerkontos anlegen? [j/N]'
    'Gib künftig in PowerShell in einem beliebigen Ordner SSH-Manager ein und drücke Enter.'
    'Installation fehlgeschlagen. Beim nächsten Versuch wird derselbe Schlüssel verwendet.'
    'Bitte einen Hostnamen oder eine IP-Adresse ohne Leerzeichen und Klammern eingeben.'
    'Passwortanmeldung prüfen … Beim Erstkontakt den Host-Fingerabdruck abgleichen.'
    'Das PowerShell-Modulverzeichnis deines Benutzerkontos fehlt in PSModulePath.'
    'Mit dem Befehl SSH-Manager kannst du dieses Skript aus jedem Ordner starten.'
    'Bitte einen SSH-Benutzernamen mit Buchstaben, Zahlen oder . _ @ - eingeben.'
    'Lade das Modul in jeder neuen Sitzung zuerst mit Import-Module SSH-Manager.'
    'Noch keine Ziele. Unter Optionen kannst du Ziele anlegen oder importieren.'
    'Das Ziel wurde inzwischen geändert oder gelöscht. Bitte erneut auswählen.'
    'Keine Treffer. Unter Optionen kannst du die Suche ändern oder leeren.'
    'Die Datei existiert bereits. Bitte einen anderen Dateinamen wählen.'
    'Ein neuer Eintrag kann bestehende Schlüsselbeschränkungen umgehen.'
    'Gib zuerst Import-Module SSH-Manager und danach SSH-Manager ein.'
    'Bitte eine gültige SSH-Manager-Exportdatei (Version 1) wählen.'
    'Erlaubt sind 1–64 Zeichen: Buchstaben, Zahlen, Punkt, _ und -.'
    'Der Speicher ist gerade in Benutzung. Bitte erneut versuchen.'
    'Der Name SSH-Manager ist durch einen anderen Befehl belegt ('
    'Fingerabdruck des Schlüssels konnte nicht gelesen werden: '
    'Schlüssel übertragen … Serverpasswort erneut eingeben.'
    'Lokale Schlüssel und Serverfreigaben bleiben erhalten.'
    'Enter übernimmt den Wert in [Klammern]. ! bricht ab.'
    '). Du kannst dieses Skript weiterhin direkt starten.'
    'Bitte eine angezeigte Zielnummer, O oder Q eingeben.'
    'Import · Gleichnamige Ziele werden übersprungen.'
    'Bitte einen gültigen SSH-Benutzernamen eingeben.'
    'Bitte einen Port zwischen 1 und 65535 eingeben.'
    'Bitte Hostname oder IP ohne Klammern eingeben.'
    'Passphrase für den neuen Schlüssel festlegen.'
    'Keine Treffer. Suche unter Optionen ändern.'
    '[Nr] Verbinden   [O] Optionen   [Q] Beenden'
    '1  Schlüssel per Serverpasswort einrichten'
    '2  Bestehende OpenSSH-Konfiguration nutzen'
    'Anmeldung mit dem neuen Schlüssel prüfen …'
    'Sprache wählen · [1] Englisch  [2] Deutsch'
    'Bitte eine angezeigte Zielnummer eingeben.'
    'Das Modulverzeichnis ist bereits belegt: '
    '. Lass das Skript an diesem Speicherort.'
    'Bitte den Pfad zu einer Datei eingeben.'
    'Schlüssel am neuen Port behalten? (j/n)'
    'Export · Alle Ziele ohne SSH-Schlüssel.'
    'Erneute Schlüsselfreigabe abgebrochen.'
    '[N] Neu   [B] Bearbeiten   [L] Löschen'
    'Dieser Kurzname ist bereits vergeben.'
    'Ungültiger öffentlicher Schlüssel in '
    '). Details stehen in der SSH-Ausgabe.'
    'Bitte einen einzelnen Wert eingeben.'
    'Kurzname passt nicht zum Dateinamen.'
    'Anmeldung mit dem Schlüssel prüfen …'
    '[S] Suchen   [I] Import   [E] Export'
    'Bitte eine angezeigte Option wählen.'
    'Das Schlüsselpaar ist unvollständig.'
    ' gespeicherten Zielen abgebrochen.'
    'Schlüsselerzeugung fehlgeschlagen.'
    'Ungültiger öffentlicher Schlüssel.'
    'Pfad zur JSON-Datei (Enter zurück)'
    'Ungültige Profildaten in Eintrag '
    'Schlüssel erneut freigeben? [j/N]'
    'Passwortanmeldung fehlgeschlagen.'
    'Kurzname passt nicht zur Datei.'
    'Bitte eine der Optionen wählen'
    'Vorhandenen Schlüssel prüfen …'
    'Bearbeiten · Nr (Enter zurück)'
    ' konnte nicht gelesen werden.'
    'Privater Schlüssel fehlt zu '
    'Löschen · Nr (Enter zurück)'
    'Keine SSH-Sitzung geöffnet.'
    'Privater Schlüssel fehlt: '
    '[O] Optionen   [Q] Beenden'
    'Suche (Enter setzt zurück)'
    'Privater Schlüssel fehlt.'
    'Benötigter Befehl fehlt ('
    'Bearbeitung abgebrochen.'
    'Der Befehl verweist auf '
    'Keine Ziele zur Auswahl.'
    'Ungültige Schlüssel-ID.'
    'Import abgeschlossen · '
    'Export abgeschlossen · '
    'Sprache (Enter zurück)'
    'Bitte 1 oder 2 wählen.'
    'Ungültige Profildatei.'
    'Ungültige Anmeldeart.'
    'SSH-Sitzung beendet.'
    'SSH beendet (Status '
    'Ungültiger Kurzname.'
    'Ungültiger Benutzer.'
    'Ziel löschen? [j/N]'
    'Ziel bearbeiten · '
    'Ungültiges Profil.'
    'Globaler Aufruf: '
    'Ungültiger Host.'
    'Ungültiger Port.'
    'Ziel löschen · '
    'Neues SSH-Ziel'
    ''\'' gespeichert.'
    '[Enter] Zurück'
    ' übersprungen'
    ' gespeichert.'
    'Import nach '
    'Host oder IP'
    'SSH-Benutzer'
    ''\'' gelöscht.'
    'SSH-Ziele ('
    '[G] Sprache'
    ' übernommen'
    'Verbinde · '
    'Verbindung'
    'Anmeldung'
    'Verwaltet'
    'Fehler · '
    'Eintrag '
    'Kurzname'
    'Optionen'
    'Suche "'
    'Suche „'
    'Auswahl'
    'Profil '
    'Ziel '\'''
    ' von '
    'Nr'
    '[Enter] Übernehmen   [Esc] Abbrechen   [Backspace] Löschen'
    'Suchbegriff: '
    '[A] Automatische Updates: Ein'
    '[A] Automatische Updates: Aus'
    '[U] Jetzt nach Updates suchen'
    'Automatische Updates aktiviert.'
    'Automatische Updates deaktiviert.'
    'Keine neue Version verfügbar.'
    'Updateprüfung fehlgeschlagen.'
)
translation_to=(
    'The short name must be 1–64 characters, starting with a letter or digit. Allowed: A–Z, 0–9, period, underscore, and hyphen.'
    'Authentication with the existing key could not be confirmed. A new entry could bypass key restrictions.'
    'Login with the intended key failed. The same key will be reused on the next attempt.'
    'Key login failed. The same key will be reused on the next attempt.'
    'Create a launcher in your user PowerShell module directory? [y/N]'
    'Run SSH-Manager from any PowerShell directory in the future.'
    'Installation failed. The same key will be reused on the next attempt.'
    'Enter a hostname or IP address without spaces or brackets.'
    'Checking password login … Verify the host fingerprint on first contact.'
    'Your user PowerShell module directory is missing from PSModulePath.'
    'The SSH-Manager command lets you start this script from any directory.'
    'Enter an SSH username using letters, digits, or . _ @ -.'
    'In each new session, load the module with Import-Module SSH-Manager.'
    'No targets yet. Add or import targets under Options.'
    'The target was changed or deleted. Select it again.'
    'No matches. Change or clear the search under Options.'
    'The file already exists. Choose another file name.'
    'A new entry could bypass key restrictions.'
    'Run Import-Module SSH-Manager, then SSH-Manager.'
    'Select a valid SSH-Manager export file (version 1).'
    'Allowed: 1–64 characters: letters, digits, period, _ and -.'
    'The store is in use. Please retry.'
    'The SSH-Manager name is already used by another command ('
    'Could not read key fingerprint: '
    'Uploading key … Enter the server password again.'
    'Local keys and server authorizations are kept.'
    'Enter accepts the value in [brackets]. ! cancels.'
    '). You can still start this script directly.'
    'Enter a target number shown above, O, or Q.'
    'Import · Duplicate target names are skipped.'
    'Enter a valid SSH username.'
    'Enter a port between 1 and 65535.'
    'Enter a hostname or IP address without brackets.'
    'Set a passphrase for the new key.'
    'No matches. Change the search under Options.'
    '[No] Connect   [O] Options   [Q] Quit'
    '1  Set up a key using the server password'
    '2  Use existing OpenSSH configuration'
    'Checking login with the new key …'
    'Choose language · [1] English  [2] German'
    'Enter a target number shown above.'
    'The module directory is already in use: '
    '. Keep the script in this location.'
    'Enter a file path.'
    'Keep key on the new port? (y/n)'
    'Export · All targets without SSH keys.'
    'Key authorization canceled.'
    '[N] New   [B] Edit   [L] Delete'
    'This short name is already in use.'
    'Invalid public key in '
    '). See SSH output for details.'
    'Enter a single value.'
    'Short name does not match the file name.'
    'Checking login with the key …'
    '[S] Search   [I] Import   [E] Export'
    'Choose an option shown above.'
    'The key pair is incomplete.'
    'saved targets.'
    'Key generation failed.'
    'Invalid public key.'
    'Path to JSON file (Enter to go back)'
    'Invalid profile data in entry '
    'Authorize key again? [y/N]'
    'Password login failed.'
    'Short name does not match the file.'
    'Choose one of the options'
    'Checking existing key …'
    'Edit · No (Enter to go back)'
    ' could not be read.'
    'Private key missing for '
    'Delete · No (Enter to go back)'
    'No SSH session was opened.'
    'Private key missing: '
    '[O] Options   [Q] Quit'
    'Search (Enter to clear)'
    'Private key missing.'
    'Required command is missing ('
    'Editing canceled.'
    'The command points to '
    'No targets to select.'
    'Invalid key ID.'
    'Import complete · '
    'Export complete · '
    'Language (Enter to go back)'
    'Choose 1 or 2.'
    'Invalid profile file.'
    'Invalid login method.'
    'SSH session ended.'
    'SSH exited (status '
    'Invalid short name.'
    'Invalid user.'
    'Delete target? [y/N]'
    'Edit target · '
    'Invalid profile.'
    'Global command: '
    'Invalid host.'
    'Invalid port.'
    'Delete target · '
    'New SSH target'
    ''\'' saved.'
    '[Enter] Back'
    ' skipped'
    ' saved.'
    'Import stopped after '
    'Host or IP'
    'SSH user'
    ''\'' deleted.'
    'SSH targets ('
    '[G] Language'
    ' imported'
    'Connecting · '
    'Connection'
    'Login'
    'Managed'
    'Error · '
    'Entry '
    'Short name'
    'Options'
    'Search "'
    'Search “'
    'Selection'
    'Profile '
    'Target '\'''
    ' of '
    'No'
    '[Enter] Apply   [Esc] Cancel   [Backspace] Delete'
    'Search: '
    '[A] Automatic updates: On'
    '[A] Automatic updates: Off'
    '[U] Check for updates now'
    'Automatic updates enabled.'
    'Automatic updates disabled.'
    'No new version available.'
    'Could not check for updates.'
)
init_language() {
    local candidate=${SSH_MANAGER_LANG:-}
    if [[ $candidate != en && $candidate != de && -f $store/language ]]; then
        candidate=$(< "$store/language")
    fi
    if [[ $candidate == en || $candidate == de ]]; then language=$candidate; else language=en; fi
}
translate_text() {
    REPLY=$1
    [[ $language == en ]] || return 0
    local i
    for ((i=0; i<${#translation_from[@]}; i++)); do
        REPLY=${REPLY//"${translation_from[i]}"/${translation_to[i]}}
    done
}
set_language() {
    local chosen=$1
    [[ $chosen == en || $chosen == de ]] || return 1
    write_file "$store/language" "$chosen" replace || return 1
    language=$chosen
}
auto_updates_enabled() {
    [[ ! -f $store/auto-update || $(< "$store/auto-update") != off ]]
}
set_auto_updates() {
    write_file "$store/auto-update" "$1" replace
}
init_language
probe_options=(-T -o ControlPath=none -o ClearAllForwardings=yes -o PermitLocalCommand=no
    -o ForwardAgent=no -o ForwardX11=no -o RemoteCommand=none)

profile_schema='
def localized($de; $en): if $lang == "de" then $de else $en end;
def valid($pattern): if type == "string" then test($pattern) else false end;
def profile:
    if type != "object" then error(localized("Ungültiges Profil."; "Invalid profile."))
    elif (.Name | valid("\\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\\z") | not) then error(localized("Ungültiger Kurzname."; "Invalid short name."))
    elif (.Server | valid("\\A[A-Za-z0-9:][A-Za-z0-9._:-]*\\z") | not) then error(localized("Ungültiger Host."; "Invalid host."))
    elif (.User | valid("\\A[A-Za-z0-9_][A-Za-z0-9._@-]*\\z") | not) then error(localized("Ungültiger Benutzer."; "Invalid user."))
    elif (.Port | if type == "number" or type == "string" then
            tostring | if test("\\A[0-9]{1,5}\\z") then tonumber | . >= 1 and . <= 65535 else false end
        else false end | not) then error(localized("Ungültiger Port."; "Invalid port."))
    elif (.Login | valid("(?i)\\A(Passwort|Schlüssel)\\z") | not) then error(localized("Ungültige Anmeldeart."; "Invalid login method."))
    else {Name, Server, User, Port: (.Port | tonumber),
        Login: (if (.Login | ascii_downcase) == "passwort" then "Passwort" else "Schlüssel" end)}
    end;
'

fail() {
    translate_text "Fehler · $*"
    printf '%s\n' "$REPLY" >&2
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
    jq -ces --arg lang "$language" --arg path "$path" --arg filename "${path##*/}" --arg snapshot "${snapshot%% *}" "$profile_schema"'
        if length != 1 then error(localized("Ungültige Profildatei."; "Invalid profile file.")) else .[0] end
        | . as $source | profile as $profile
        | $profile + {
            KeyId: (if $source.KeyId == null then
                ($profile.Name | ascii_downcase) as $name
                | if ($filename | ascii_downcase) == ("ziel-" + $name + ".json") then $name
                    else error(localized("Kurzname passt nicht zur Datei."; "Short name does not match the file.")) end
                elif ($source.KeyId | valid("\\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\\z")) then $source.KeyId
                else error(localized("Ungültige Schlüssel-ID."; "Invalid key ID.")) end),
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
            translate_text "Profil ${path##*/} konnte nicht gelesen werden."
            printf '%s\n' "$REPLY" >&2
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
    document=$(list_records | jq -s --arg lang "$language" "$profile_schema"'{
        Version: 1, Targets: (map(profile) | sort_by(.Name | ascii_downcase))
    }') || return 1
    write_file "$path" "$document" create && jq '.Targets | length' <<< "$document"
}

import_targets() {
    local path=$1 profiles
    profiles=$(jq -ces --arg lang "$language" "$profile_schema"'
        if length == 1 and (.[0] | type) == "object" and .[0].Version == 1 and (.[0].Targets | type) == "array" then
            .[0].Targets | to_entries | map(.key as $index | try (.value | profile)
                catch error(localized("Eintrag \($index + 1) · \(.)"; "Entry \($index + 1) · \(.)")))
        else error(localized("Bitte eine gültige SSH-Manager-Exportdatei (Version 1) wählen."; "Select a valid SSH-Manager export file (version 1).")) end
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
        [[ ${REPLY,,} == j || ${REPLY,,} == ja || ${REPLY,,} == y || ${REPLY,,} == yes ]] || return 1
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
    translate_text "$1"
    local text=$REPLY part
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
    translate_text "$1"
    local prompt=$REPLY
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
            read_field 'Schlüssel am neuen Port behalten? (j/n)' j '^([jJ]([aA])?|[yY]([eE][sS])?|[nN]([eE][iI][nN]|[oO])?)$' 'Bitte j oder n wählen.' || return 0
            if [[ ${REPLY,,} == n || ${REPLY,,} == nein || ${REPLY,,} == no ]]; then keep_key=no; fi
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
    menu_text "SSH-Manager · v$manager_version"
    if [[ -n $available_update_version ]]; then
        if [[ $language == de ]]; then
            menu_text "Veraltete Version! Update v$available_update_version verfügbar."
        else
            menu_text "Outdated version! Update v$available_update_version available."
        fi
    fi
    if [[ -n $filter ]]; then menu_text "Suche „$filter“ · $# von $total"; else menu_text "SSH-Ziele ($total)"; fi
    printf '\n'
    for row in "$@"; do
        ((number += 1))
        fields=$(target_fields "$row") || return 1
        IFS=$'\t' read -r name server user port login _ <<< "$fields"
        endpoint=$(address "$server" "$user" "$port")
        label=OpenSSH
        if [[ $login == Passwort ]]; then translate_text 'Verwaltet'; label=$REPLY; fi
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
        menu_text '[Nr] Verbinden   [O] Optionen   [Q] Beenden'
    else
        if [[ -n $filter ]]; then menu_text 'Keine Treffer. Suche unter Optionen ändern.'; else menu_text 'Noch keine Ziele. Unter Optionen kannst du Ziele anlegen oder importieren.'; fi
        printf '\n'
        menu_text '[O] Optionen   [Q] Beenden'
    fi
}

read_option() {
    printf '\n'
    menu_text Optionen
    menu_text '[N] Neu   [B] Bearbeiten   [L] Löschen'
    menu_text '[S] Suchen   [I] Import   [E] Export'
    menu_text '[G] Sprache'
    if auto_updates_enabled; then
        menu_text '[A] Automatische Updates: Ein'
    else
        menu_text '[A] Automatische Updates: Aus'
    fi
    menu_text '[U] Jetzt nach Updates suchen'
    menu_text '[Enter] Zurück'
    while ask Option; do
        case ${REPLY,,} in ''|n|b|l|s|i|e|g|a|u) return 0 ;; esac
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

filter_records() {
    jq -c --arg filter "$2" '
        ($filter | ascii_downcase | split(" ") | map(select(length > 0))) as $terms
        | .[] | select(
            ([.Name, (.User + "@" + .Server + ":" + (.Port | tostring)),
              .Server, .User, (.Port | tostring), .Login,
              (if .Login == "Passwort" then "Verwaltet Managed" else "OpenSSH" end)]
             | join(" ") | ascii_downcase) as $text
            | all($terms[]; . as $term | $text | contains($term))
        )' <<< "$1"
}

read_live_search() {
    local records=$1 total=$2 query=$3 key rows
    local -a matches=()
    if [[ ! -t 0 || ! -t 1 ]]; then
        ask 'Suche (Enter setzt zurück)'
        return $?
    fi
    while true; do
        get_width
        rows=$(filter_records "$records" "$query") || return 1
        matches=()
        if [[ -n $rows ]]; then mapfile -t matches <<< "$rows"; fi
        printf '\033[H\033[2J'
        show_targets "$total" "$query" "${matches[@]}" || return 1
        menu_text '[Enter] Übernehmen   [Esc] Abbrechen   [Backspace] Löschen'
        translate_text 'Suchbegriff: '
        printf '%s%s' "$REPLY" "$query"
        IFS= read -rsn1 key || return 1
        case $key in
            '') REPLY=$query; trim; printf '\n'; return 0 ;;
            $'\e') printf '\n'; return 2 ;;
            $'\177'|$'\b') [[ -z $query ]] || query=${query%?} ;;
            *) if [[ $key != [[:cntrl:]] ]]; then query+=$key; fi ;;
        esac
    done
}

start_manager() {
    local records rows total filter='' action selection index target name status
    local -a visible=()
    while true; do
        get_width
        records=$(list_records | jq -cs 'sort_by(.Name | ascii_downcase)') || return 1
        total=$(jq length <<< "$records") || return 1
        rows=$(filter_records "$records" "$filter") || return 1
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
                    a)
                        if auto_updates_enabled; then
                            set_auto_updates off || return 1
                            menu_text 'Automatische Updates deaktiviert.'
                        else
                            set_auto_updates on || return 1
                            menu_text 'Automatische Updates aktiviert.'
                        fi
                        continue ;;
                    u) check_update manual; continue ;;
                    g)
                        menu_text 'Sprache wählen · [1] Englisch  [2] Deutsch'
                        ask 'Sprache (Enter zurück)' || return 0
                        case $REPLY in
                            1) set_language en || return 1 ;;
                            2) set_language de || return 1 ;;
                            '') ;;
                            *) menu_text 'Bitte 1 oder 2 wählen.' ;;
                        esac
                        continue ;;
                    s)
                        if read_live_search "$records" "$total" "$filter"; then
                            filter=${REPLY//[[:cntrl:]]/}
                        else
                            status=$?
                            ((status == 2)) || return 0
                        fi
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
                if [[ ${REPLY,,} == j || ${REPLY,,} == ja || ${REPLY,,} == y || ${REPLY,,} == yes ]]; then
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
    mkdir -p -- "$store" || return 1
    if auto_updates_enabled; then check_update; fi
    start_manager
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
