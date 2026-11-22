#requires -Version 5.1

$ErrorActionPreference = 'Stop'
$store = Join-Path (Join-Path $HOME '.ssh') 'ssh-manager'
$script:ManagerScriptPath = $PSCommandPath

# Match version to latest stable release.
$script:ManagerVersion = '0.3.3'
$script:AvailableUpdateVersion = $null
function Test-ManagerUpdate {
    $script:AvailableUpdateVersion = $null
    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/eb-88/SSH-Manager/releases/latest' -TimeoutSec 5 -Headers @{ 'User-Agent' = 'SSH-Manager' }
        $tag = [string]$release.tag_name
        if ($tag -notmatch '^v[0-9]+[.][0-9]+[.][0-9]+$') { return }
        $newVersion = $tag.Substring(1)
        if ([version]$newVersion -le [version]$script:ManagerVersion) { return }
        $script:AvailableUpdateVersion = $newVersion
        $prompt = if ($script:Language -eq 'de') { "Version v$newVersion verfügbar (installiert: v$script:ManagerVersion). Jetzt installieren? [j/N]" } else { "Version v$newVersion available (installed: v$script:ManagerVersion). Install now? [y/N]" }
        if ((Read-Host $prompt) -notin 'y', 'yes', 'j', 'ja') { return }
        $destination = $script:ManagerScriptPath
        if (-not $destination -or -not [IO.File]::Exists($destination)) { throw 'Could not locate the installed SSH Manager script.' }
        $temporary = Join-Path (Split-Path -Parent $destination) ([IO.Path]::GetRandomFileName())
        try {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/eb-88/SSH-Manager/$tag/SSH-Manager.ps1" -OutFile $temporary -TimeoutSec 15 -UseBasicParsing
            $downloaded = [IO.File]::ReadAllText($temporary)
            $expected = "$([char]36)script:ManagerVersion = '$newVersion'"
            if (-not ($downloaded.Split([char]10) | Where-Object { $_.Trim() -ceq $expected })) { throw 'Downloaded version mismatch.' }
            $tokens = $null; $parseErrors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($temporary, [ref]$tokens, [ref]$parseErrors)
            if ($parseErrors.Count) { throw 'Downloaded PowerShell script is invalid.' }
            [IO.File]::Replace($temporary, $destination, [NullString]::Value)
            $script:AvailableUpdateVersion = $null
            Write-Host $(if ($script:Language -eq 'de') { "Version v$newVersion installiert. Beim nächsten Start aktiv." } else { "Installed v$newVersion. It will run on the next launch." })
        } finally {
            if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
        }
    } catch {
        Write-Warning $(if ($script:Language -eq 'de') { "Update fehlgeschlagen: $($_.Exception.Message)" } else { "Update failed: $($_.Exception.Message)" })
    }
}


# Display-only localization. Persisted profile and export values never change.
$script:Language = 'en'
$script:English = @{
    'Der Kurzname braucht 1–64 Zeichen und beginnt mit einem Buchstaben oder einer Zahl. Erlaubt sind A–Z, 0–9, Punkt, Unterstrich und Bindestrich.' = 'The short name must be 1–64 characters, starting with a letter or digit. Allowed: A–Z, 0–9, period, underscore, and hyphen.'
    'Die Anmeldung mit dem bisherigen Schlüssel konnte nicht bestätigt werden. Ein neuer Eintrag kann bestehende Schlüsselbeschränkungen umgehen.' = 'Authentication with the existing key could not be confirmed. A new entry could bypass key restrictions.'
    'Anmeldung mit dem vorgesehenen Schlüssel fehlgeschlagen. Beim nächsten Versuch wird derselbe Schlüssel verwendet.' = 'Login with the intended key failed. The same key will be reused on the next attempt.'
    'Schlüsselanmeldung fehlgeschlagen. Beim nächsten Versuch wird derselbe Schlüssel verwendet.' = 'Key login failed. The same key will be reused on the next attempt.'
    'Dafür einen Verweis im PowerShell-Modulverzeichnis deines Benutzerkontos anlegen? [j/N]' = 'Create a launcher in your user PowerShell module directory? [y/N]'
    'Gib künftig in PowerShell in einem beliebigen Ordner SSH-Manager ein und drücke Enter.' = 'Run SSH-Manager from any PowerShell directory in the future.'
    'Installation fehlgeschlagen. Beim nächsten Versuch wird derselbe Schlüssel verwendet.' = 'Installation failed. The same key will be reused on the next attempt.'
    'Bitte einen Hostnamen oder eine IP-Adresse ohne Leerzeichen und Klammern eingeben.' = 'Enter a hostname or IP address without spaces or brackets.'
    'Passwortanmeldung prüfen … Beim Erstkontakt den Host-Fingerabdruck abgleichen.' = 'Checking password login … Verify the host fingerprint on first contact.'
    'Das PowerShell-Modulverzeichnis deines Benutzerkontos fehlt in PSModulePath.' = 'Your user PowerShell module directory is missing from PSModulePath.'
    'Mit dem Befehl SSH-Manager kannst du dieses Skript aus jedem Ordner starten.' = 'The SSH-Manager command lets you start this script from any directory.'
    'Bitte einen SSH-Benutzernamen mit Buchstaben, Zahlen oder . _ @ - eingeben.' = 'Enter an SSH username using letters, digits, or . _ @ -.'
    'Lade das Modul in jeder neuen Sitzung zuerst mit Import-Module SSH-Manager.' = 'In each new session, load the module with Import-Module SSH-Manager.'
    'Noch keine Ziele. Unter Optionen kannst du Ziele anlegen oder importieren.' = 'No targets yet. Add or import targets under Options.'
    'Das Ziel wurde inzwischen geändert oder gelöscht. Bitte erneut auswählen.' = 'The target was changed or deleted. Select it again.'
    'Keine Treffer. Unter Optionen kannst du die Suche ändern oder leeren.' = 'No matches. Change or clear the search under Options.'
    'Die Datei existiert bereits. Bitte einen anderen Dateinamen wählen.' = 'The file already exists. Choose another file name.'
    'Ein neuer Eintrag kann bestehende Schlüsselbeschränkungen umgehen.' = 'A new entry could bypass key restrictions.'
    'Gib zuerst Import-Module SSH-Manager und danach SSH-Manager ein.' = 'Run Import-Module SSH-Manager, then SSH-Manager.'
    'Bitte eine gültige SSH-Manager-Exportdatei (Version 1) wählen.' = 'Select a valid SSH-Manager export file (version 1).'
    'Erlaubt sind 1–64 Zeichen: Buchstaben, Zahlen, Punkt, _ und -.' = 'Allowed: 1–64 characters: letters, digits, period, _ and -.'
    'Der Speicher ist gerade in Benutzung. Bitte erneut versuchen.' = 'The store is in use. Please retry.'
    'Der Name SSH-Manager ist durch einen anderen Befehl belegt (' = 'The SSH-Manager name is already used by another command ('
    'Fingerabdruck des Schlüssels konnte nicht gelesen werden: ' = 'Could not read key fingerprint: '
    'Schlüssel übertragen … Serverpasswort erneut eingeben.' = 'Uploading key … Enter the server password again.'
    'Lokale Schlüssel und Serverfreigaben bleiben erhalten.' = 'Local keys and server authorizations are kept.'
    'Enter übernimmt den Wert in [Klammern]. ! bricht ab.' = 'Enter accepts the value in [brackets]. ! cancels.'
    '). Du kannst dieses Skript weiterhin direkt starten.' = '). You can still start this script directly.'
    'Bitte eine angezeigte Zielnummer, O oder Q eingeben.' = 'Enter a target number shown above, O, or Q.'
    'Import · Gleichnamige Ziele werden übersprungen.' = 'Import · Duplicate target names are skipped.'
    'Bitte einen gültigen SSH-Benutzernamen eingeben.' = 'Enter a valid SSH username.'
    'Bitte einen Port zwischen 1 und 65535 eingeben.' = 'Enter a port between 1 and 65535.'
    'Bitte Hostname oder IP ohne Klammern eingeben.' = 'Enter a hostname or IP address without brackets.'
    'Passphrase für den neuen Schlüssel festlegen.' = 'Set a passphrase for the new key.'
    'Keine Treffer. Suche unter Optionen ändern.' = 'No matches. Change the search under Options.'
    '[Nr] Verbinden   [O] Optionen   [Q] Beenden' = '[No] Connect   [O] Options   [Q] Quit'
    '1  Schlüssel per Serverpasswort einrichten' = '1  Set up a key using the server password'
    '2  Bestehende OpenSSH-Konfiguration nutzen' = '2  Use existing OpenSSH configuration'
    'Anmeldung mit dem neuen Schlüssel prüfen …' = 'Checking login with the new key …'
    'Sprache wählen · [1] Englisch  [2] Deutsch' = 'Choose language · [1] English  [2] German'
    'Bitte eine angezeigte Zielnummer eingeben.' = 'Enter a target number shown above.'
    'Das Modulverzeichnis ist bereits belegt: ' = 'The module directory is already in use: '
    '. Lass das Skript an diesem Speicherort.' = '. Keep the script in this location.'
    'Bitte den Pfad zu einer Datei eingeben.' = 'Enter a file path.'
    'Schlüssel am neuen Port behalten? (j/n)' = 'Keep key on the new port? (y/n)'
    'Export · Alle Ziele ohne SSH-Schlüssel.' = 'Export · All targets without SSH keys.'
    'Erneute Schlüsselfreigabe abgebrochen.' = 'Key authorization canceled.'
    '[N] Neu   [B] Bearbeiten   [L] Löschen' = '[N] New   [B] Edit   [L] Delete'
    'Dieser Kurzname ist bereits vergeben.' = 'This short name is already in use.'
    'Ungültiger öffentlicher Schlüssel in ' = 'Invalid public key in '
    '). Details stehen in der SSH-Ausgabe.' = '). See SSH output for details.'
    'Bitte einen einzelnen Wert eingeben.' = 'Enter a single value.'
    'Kurzname passt nicht zum Dateinamen.' = 'Short name does not match the file name.'
    'Anmeldung mit dem Schlüssel prüfen …' = 'Checking login with the key …'
    '[S] Suchen   [I] Import   [E] Export' = '[S] Search   [I] Import   [E] Export'
    'Bitte eine angezeigte Option wählen.' = 'Choose an option shown above.'
    'Das Schlüsselpaar ist unvollständig.' = 'The key pair is incomplete.'
    ' gespeicherten Zielen abgebrochen.' = 'saved targets.'
    'Schlüsselerzeugung fehlgeschlagen.' = 'Key generation failed.'
    'Ungültiger öffentlicher Schlüssel.' = 'Invalid public key.'
    'Pfad zur JSON-Datei (Enter zurück)' = 'Path to JSON file (Enter to go back)'
    'Ungültige Profildaten in Eintrag ' = 'Invalid profile data in entry '
    'Schlüssel erneut freigeben? [j/N]' = 'Authorize key again? [y/N]'
    'Passwortanmeldung fehlgeschlagen.' = 'Password login failed.'
    'Kurzname passt nicht zur Datei.' = 'Short name does not match the file.'
    'Bitte eine der Optionen wählen' = 'Choose one of the options'
    'Vorhandenen Schlüssel prüfen …' = 'Checking existing key …'
    'Bearbeiten · Nr (Enter zurück)' = 'Edit · No (Enter to go back)'
    ' konnte nicht gelesen werden.' = ' could not be read.'
    'Privater Schlüssel fehlt zu ' = 'Private key missing for '
    'Löschen · Nr (Enter zurück)' = 'Delete · No (Enter to go back)'
    'Keine SSH-Sitzung geöffnet.' = 'No SSH session was opened.'
    'Privater Schlüssel fehlt: ' = 'Private key missing: '
    '[O] Optionen   [Q] Beenden' = '[O] Options   [Q] Quit'
    'Suche (Enter setzt zurück)' = 'Search (Enter to clear)'
    '[Enter] Übernehmen   [Esc] Abbrechen   [Backspace] Löschen' = '[Enter] Apply   [Esc] Cancel   [Backspace] Delete'
    'Suchbegriff: ' = 'Search: '
    'Privater Schlüssel fehlt.' = 'Private key missing.'
    'Benötigter Befehl fehlt (' = 'Required command is missing ('
    'Bearbeitung abgebrochen.' = 'Editing canceled.'
    'Der Befehl verweist auf ' = 'The command points to '
    'Keine Ziele zur Auswahl.' = 'No targets to select.'
    'Ungültige Schlüssel-ID.' = 'Invalid key ID.'
    'Import abgeschlossen · ' = 'Import complete · '
    'Export abgeschlossen · ' = 'Export complete · '
    'Sprache (Enter zurück)' = 'Language (Enter to go back)'
    'Bitte 1 oder 2 wählen.' = 'Choose 1 or 2.'
    'Ungültige Profildatei.' = 'Invalid profile file.'
    'Ungültige Anmeldeart.' = 'Invalid login method.'
    'SSH-Sitzung beendet.' = 'SSH session ended.'
    'SSH beendet (Status ' = 'SSH exited (status '
    'Ungültiger Kurzname.' = 'Invalid short name.'
    'Ungültiger Benutzer.' = 'Invalid user.'
    'Ziel löschen? [j/N]' = 'Delete target? [y/N]'
    'Ziel bearbeiten · ' = 'Edit target · '
    'Ungültiges Profil.' = 'Invalid profile.'
    'Globaler Aufruf: ' = 'Global command: '
    'Ungültiger Host.' = 'Invalid host.'
    'Ungültiger Port.' = 'Invalid port.'
    'Ziel löschen · ' = 'Delete target · '
    'Neues SSH-Ziel' = 'New SSH target'
    ''' gespeichert.' = ''' saved.'
    '[Enter] Zurück' = '[Enter] Back'
    ' übersprungen' = ' skipped'
    ' gespeichert.' = ' saved.'
    'Import nach ' = 'Import stopped after '
    'Host oder IP' = 'Host or IP'
    'SSH-Benutzer' = 'SSH user'
    ''' gelöscht.' = ''' deleted.'
    'SSH-Ziele (' = 'SSH targets ('
    '[G] Sprache' = '[G] Language'
    ' übernommen' = ' imported'
    'Verbinde · ' = 'Connecting · '
    'Verbindung' = 'Connection'
    'Anmeldung' = 'Login'
    'Verwaltet' = 'Managed'
    'Fehler · ' = 'Error · '
    'Eintrag ' = 'Entry '
    'Kurzname' = 'Short name'
    'Optionen' = 'Options'
    'Suche "' = 'Search "'
    'Suche „' = 'Search “'
    'Auswahl' = 'Selection'
    'Profil ' = 'Profile '
    'Ziel ''' = 'Target '''
    ' von ' = ' of '
    'Nr' = 'No'
}
$script:TranslationKeys = @($script:English.Keys | Sort-Object Length -Descending)
function Initialize-Language {
    $script:Language = 'en'
    $candidate = $env:SSH_MANAGER_LANG
    if ($candidate -notin 'en', 'de') {
        $path = Join-Path $store 'language'
        if ([IO.File]::Exists($path)) { $candidate = [IO.File]::ReadAllText($path).Trim() }
    }
    if ($candidate -in 'en', 'de') { $script:Language = $candidate.ToLowerInvariant() }
}
function Translate-Text([string]$text) {
    if ($script:Language -ne 'en') { return $text }
    foreach ($key in $script:TranslationKeys) { $text = $text.Replace($key, $script:English[$key]) }
    $text
}
function Set-Language([string]$value) {
    if ($value -notin 'en', 'de') { throw 'Invalid language.' }
    [void][IO.Directory]::CreateDirectory($store)
    [IO.File]::WriteAllText((Join-Path $store 'language'), $value)
    $script:Language = $value
}
Initialize-Language

function Assert-TargetField($field, $value) {
    if ($value -is [array]) { throw 'Bitte einen einzelnen Wert eingeben.' }
    switch ($field) {
        'Name' {
            if ($value -notmatch '\A[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}\z') {
                throw 'Der Kurzname braucht 1–64 Zeichen und beginnt mit einem Buchstaben oder einer Zahl. Erlaubt sind A–Z, 0–9, Punkt, Unterstrich und Bindestrich.'
            }
        }
        'Server' {
            if ($value -notmatch '\A[a-zA-Z0-9:][a-zA-Z0-9._:-]*\z') {
                throw 'Bitte einen Hostnamen oder eine IP-Adresse ohne Leerzeichen und Klammern eingeben.'
            }
        }
        'User' {
            if ($value -notmatch '\A[a-zA-Z0-9_][a-zA-Z0-9._@-]*\z') {
                throw 'Bitte einen SSH-Benutzernamen mit Buchstaben, Zahlen oder . _ @ - eingeben.'
            }
        }
        'Port' {
            if ($value -notmatch '\A[0-9]{1,5}\z' -or [int]$value -lt 1 -or [int]$value -gt 65535) {
                throw 'Bitte einen Port zwischen 1 und 65535 eingeben.'
            }
        }
    }
}

function Assert-Target($target) {
    foreach ($field in 'Name', 'Server', 'User', 'Port') {
        Assert-TargetField $field $target.$field
    }
    if ($target.Login -notin 'Passwort', 'Schlüssel') { throw 'Ungültige Anmeldeart.' }
    if ($null -ne $target.KeyId -and ($target.KeyId -is [array] -or $target.KeyId -notmatch '\A[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}\z')) {
        throw 'Ungültige Schlüssel-ID.'
    }
}

function Open-StoreLock {
    [void][IO.Directory]::CreateDirectory($store)
    [IO.File]::Open((Join-Path $store 'ziele.lock'), 'OpenOrCreate', 'Write', 'None')
}

function Assert-CurrentTarget($original) {
    if (-not [IO.File]::Exists($original.FilePath) -or
        [IO.File]::ReadAllText($original.FilePath) -cne $original.Snapshot) {
        throw 'Das Ziel wurde inzwischen geändert oder gelöscht. Bitte erneut auswählen.'
    }
}

function Assert-AvailableTargetName($name, $original) {
    foreach ($target in Get-Targets) {
        if ($target.Name -eq $name -and $target.FilePath -ne $original.FilePath) {
            throw 'Dieser Kurzname ist bereits vergeben.'
        }
    }
}

function Save-Target($target, $original, $keepKey = $true) {
    Assert-Target $target
    $lock = Open-StoreLock
    try {
        if ($original) { Assert-CurrentTarget $original }
        Assert-AvailableTargetName $target.Name $original
        Write-TargetRecord $target $original $keepKey
    } finally {
        $lock.Dispose()
    }
}

function Write-TargetRecord($target, $original, $keepKey) {
    $temp = Join-Path $store ([guid]::NewGuid().ToString())
    try {
        $record = $target | Select-Object Name, Server, User, Port, Login, KeyId
        if ($keepKey -and $original -and $original.Server -eq $target.Server -and $original.User -ceq $target.User) {
            $record.KeyId = $original.KeyId
        } else {
            $record.KeyId = [guid]::NewGuid().ToString('N')
        }
        [IO.File]::WriteAllText($temp, ($record | ConvertTo-Json))
        if ($original) {
            [IO.File]::Replace($temp, $original.FilePath, [NullString]::Value)
        } else {
            $path = Join-Path $store "ziel-$($target.Name.ToLowerInvariant()).json"
            if ([IO.File]::Exists($path)) { $path = Join-Path $store "ziel-$($record.KeyId).json" }
            [IO.File]::Move($temp, $path)
        }
    } finally {
        [IO.File]::Delete($temp)
    }
}

function Remove-Target($original) {
    $lock = Open-StoreLock
    try {
        Assert-CurrentTarget $original
        [IO.File]::Delete($original.FilePath)
    } finally {
        $lock.Dispose()
    }
}

function Get-Targets {
    if (Test-Path -LiteralPath $store) {
        foreach ($file in (Get-ChildItem -LiteralPath $store -Filter 'ziel-*.json' -File)) {
            try {
                $snapshot = [IO.File]::ReadAllText($file.FullName)
                $target = $snapshot | ConvertFrom-Json
                Assert-Target $target
                if ($null -eq $target.KeyId) {
                    if ($file.BaseName -ne "ziel-$($target.Name)") { throw 'Kurzname passt nicht zum Dateinamen.' }
                    $target | Add-Member KeyId $target.Name.ToLowerInvariant()
                }
                $target | Add-Member FilePath $file.FullName
                $target | Add-Member Snapshot $snapshot
            } catch {
                Write-Warning (Translate-Text "$($file.Name): $($_.Exception.Message)")
                continue
            }
            $target
        }
    }
}

function Resolve-TransferPath($inputPath) {
    $provider = $null
    $path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $inputPath.Trim().Trim('"'), [ref]$provider, [ref]$null)
    if ($provider.Name -ne 'FileSystem') { throw 'Bitte den Pfad zu einer Datei eingeben.' }
    $path
}

function Export-Targets($path) {
    if ([IO.File]::Exists($path)) { throw 'Die Datei existiert bereits. Bitte einen anderen Dateinamen wählen.' }
    $profiles = @(Get-Targets | Sort-Object Name | ForEach-Object {
        [ordered]@{
            Name = [string]$_.Name
            Server = [string]$_.Server
            User = [string]$_.User
            Port = [int]$_.Port
            Login = [string]$_.Login
        }
    })
    $temp = Join-Path ([IO.Path]::GetDirectoryName($path)) ([guid]::NewGuid().ToString())
    try {
        $json = [ordered]@{ Version = 1; Targets = $profiles } | ConvertTo-Json -Depth 3
        [IO.File]::WriteAllText($temp, $json)
        [IO.File]::Move($temp, $path)
    } finally {
        [IO.File]::Delete($temp)
    }
    $profiles.Count
}

function Import-Targets($path) {
    $json = [IO.File]::ReadAllText($path)
    $formatError = 'Bitte eine gültige SSH-Manager-Exportdatei (Version 1) wählen.'
    if (-not $json.TrimStart().StartsWith('{')) { throw $formatError }
    try { $document = ConvertFrom-Json -InputObject $json } catch { throw $formatError }
    if ($document -isnot [pscustomobject] -or $document.Targets -isnot [array] -or
        ($document.Version -isnot [int] -and $document.Version -isnot [long]) -or $document.Version -ne 1) {
        throw $formatError
    }
    $number = 0
    $profiles = @(foreach ($item in $document.Targets) {
        $number++
        if ($item -isnot [pscustomobject] -or $item.Name -isnot [string] -or $item.Server -isnot [string] -or
            $item.User -isnot [string] -or $item.Login -isnot [string] -or
            ($item.Port -isnot [string] -and $item.Port -isnot [int] -and $item.Port -isnot [long])) {
            throw "Ungültige Profildaten in Eintrag $number."
        }
        $profile = $item | Select-Object Name, Server, User, Port, Login
        try { Assert-Target $profile } catch { throw "Eintrag $number · $($_.Exception.Message)" }
        $profile
    })

    $added = 0
    if ($profiles.Count) {
        $lock = Open-StoreLock
        try {
            $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($target in Get-Targets) { [void]$names.Add($target.Name) }
            foreach ($profile in $profiles) {
                if ($names.Add($profile.Name)) {
                    Write-TargetRecord $profile
                    $added++
                }
            }
        } catch {
            throw "Import nach $added gespeicherten Zielen abgebrochen. $($_.Exception.Message)"
        } finally {
            $lock.Dispose()
        }
    }
    [pscustomobject]@{ Added = $added; Skipped = $profiles.Count - $added }
}

function Get-MenuWidth {
    try {
        $width = $Host.UI.RawUI.WindowSize.Width
        if ($width -gt 0) { return [Math]::Max(4, [Math]::Min(104, $width)) }
    } catch {
        # Manche Hosts stellen keine Fenstergröße bereit.
    }
    80
}

function Write-MenuText([string]$text, $width = (Get-MenuWidth), $color) {
    $text = Translate-Text $text
    $style = @{}
    if ($color) { $style.ForegroundColor = $color }
    while ($text.Length -gt $width) {
        $breakAt = $text.LastIndexOf(' ', $width)
        if ($breakAt -le 0 -or $text.Substring(0, $breakAt).Trim().Length -eq 0) { $breakAt = $width }
        Write-Host $text.Substring(0, $breakAt).TrimEnd() @style
        $text = $text.Substring($breakAt).TrimStart()
    }
    Write-Host $text @style
}

function Read-MenuInput($prompt, $width = (Get-MenuWidth)) {
    $prompt = Translate-Text $prompt
    if ($prompt.Length + 2 -gt $width) {
        Write-MenuText $prompt $width
        $prompt = '>'
    }
    Read-Host $prompt
}

function Read-Field($label, $current, $field, $choices, $original) {
    if ($null -ne $current) { $label += " [$current]" }
    while ($true) {
        $inputText = Read-MenuInput $label
        if ($null -eq $inputText) { return }
        $value = $inputText.Trim()
        if ($value -eq '!') {
            Write-MenuText 'Bearbeitung abgebrochen.'
            return
        }
        if ($value -eq '' -and $null -ne $current) { $value = $current }
        try {
            if ($choices) {
                if ($value -notin $choices) { throw "Bitte eine der Optionen wählen ($($choices -join ', '))." }
            } else {
                Assert-TargetField $field $value
                if ($field -eq 'Name') { Assert-AvailableTargetName $value $original }
            }
            return $value
        } catch {
            Write-MenuText $_.Exception.Message
        }
    }
}

function Edit-Target($original) {
    Write-Host ''
    $title = if ($original) { "Ziel bearbeiten · $($original.Name)" } else { 'Neues SSH-Ziel' }
    Write-MenuText $title -color Cyan
    Write-MenuText 'Enter übernimmt den Wert in [Klammern]. ! bricht ab.'
    $fields = [ordered]@{ Name = 'Kurzname'; Server = 'Host oder IP'; User = 'SSH-Benutzer'; Port = 'Port' }
    $record = [pscustomobject]@{ Name = $null; Server = $null; User = $null; Port = $null; Login = $null }
    foreach ($field in $fields.Keys) {
        $current = $original.$field
        if ($field -eq 'Port' -and $null -eq $current) { $current = 22 }
        $record.$field = Read-Field $fields[$field] $current $field -original $original
        if ($null -eq $record.$field) { return }
    }

    Write-MenuText '1  Schlüssel per Serverpasswort einrichten'
    Write-MenuText '2  Bestehende OpenSSH-Konfiguration nutzen'
    $defaultLogin = if ($original.Login -eq 'Schlüssel') { '2' } else { '1' }
    $choice = Read-Field 'Anmeldung' $defaultLogin -choices @('1', '2')
    if ($null -eq $choice) { return }
    $record.Login = if ($choice -eq '2') { 'Schlüssel' } else { 'Passwort' }

    $keepKey = $true
    if ($original -and $record.Login -eq 'Passwort' -and $record.Server -eq $original.Server -and
        $record.User -ceq $original.User -and [int]$record.Port -ne [int]$original.Port) {
        $answer = Read-Field 'Schlüssel am neuen Port behalten? (j/n)' 'j' -choices @('j', 'n', 'ja', 'nein', 'y', 'yes', 'no')
        if ($null -eq $answer) { return }
        $keepKey = $answer -in 'j', 'ja', 'y', 'yes'
    }
    Save-Target $record $original $keepKey
    Write-MenuText "Ziel '$($record.Name)' gespeichert."
}

function Test-TargetKey($key, $connection, $identity) {
    # Der SSH-Status kann vom erzwungenen Serverbefehl stammen. Entscheidend ist das Anmeldeprotokoll.
    $PSNativeCommandUseErrorActionPreference = $false
    $description = & ssh-keygen -l -E sha256 -f $key
    if ($LASTEXITCODE -ne 0 -or $description -notmatch '^\d+ (SHA256:\S+) ') {
        throw "Fingerabdruck des Schlüssels konnte nicht gelesen werden: $key"
    }
    $expected = $Matches[1]
    $log = [IO.Path]::GetTempFileName()
    try {
        & ssh -vvv -E $log -T -o ControlPath=none -o FingerprintHash=sha256 @identity @connection 'exit 0' | Out-Host
        # Weitere IdentityFile-Einträge können trotz IdentitiesOnly zur Anmeldung führen.
        $signer = '^debug3: sign_and_send_pubkey: (?:using \S+ with )?\S+ (SHA256:\S+)\s*$'
        $success = '^(?:Authenticated to .+ using "publickey"|debug1: Authentication succeeded \(publickey\))\.$'
        $evidence = @(Select-String -LiteralPath $log -Pattern $signer, $success -CaseSensitive | Select-Object -Last 2)
        return ($evidence.Count -eq 2 -and $evidence[0].Pattern -eq $signer -and
            $evidence[1].Pattern -eq $success -and $evidence[0].Matches[0].Groups[1].Value -ceq $expected)
    } finally {
        [IO.File]::Delete($log)
    }
}

function Install-TargetKey($key, $connection, $identity, $endpoint) {
    $ready = "$key.ready"
    # Der exklusive Zugriff verhindert zwei gleichzeitige Schlüsselgeneratoren für dasselbe Ziel.
    $lock = [IO.File]::Open("$key.lock", 'OpenOrCreate', 'Write', 'None')
    try {
        if ([IO.File]::Exists($ready) -and [IO.File]::ReadAllText($ready) -ceq $endpoint) { return }
        $existingKey = [IO.File]::Exists($key)
        if ($existingKey) {
            Write-MenuText 'Vorhandenen Schlüssel prüfen …'
            if (Test-TargetKey $key $connection $identity) {
                [IO.File]::WriteAllText($ready, $endpoint)
                return
            }
            Write-MenuText 'Die Anmeldung mit dem bisherigen Schlüssel konnte nicht bestätigt werden. Ein neuer Eintrag kann bestehende Schlüsselbeschränkungen umgehen.'
            $answer = Read-MenuInput 'Schlüssel erneut freigeben? [j/N]'
            if ($answer -notin 'j', 'ja', 'y', 'yes') { throw 'Erneute Schlüsselfreigabe abgebrochen.' }
        }
        $password = @('-o', 'PreferredAuthentications=password,keyboard-interactive', '-o', 'ControlPath=none')
        Write-MenuText 'Passwortanmeldung prüfen … Beim Erstkontakt den Host-Fingerabdruck abgleichen.'
        & ssh -T @password @connection 'exit 0'
        if ($LASTEXITCODE -ne 0) { throw 'Passwortanmeldung fehlgeschlagen.' }

        if (-not $existingKey) {
            if ([IO.File]::Exists("$key.pub")) { throw "Privater Schlüssel fehlt zu $key.pub." }
            Write-MenuText 'Passphrase für den neuen Schlüssel festlegen.'
            & ssh-keygen -t ed25519 -f $key
            if ($LASTEXITCODE -ne 0) { throw 'Schlüsselerzeugung fehlgeschlagen.' }
        }
        $public = [IO.File]::ReadAllText("$key.pub").Trim()
        if ($public -cnotmatch '\Assh-ed25519 ([A-Za-z0-9+/]+={0,2})(?: [^\r\n]*)?\z') {
            throw "Ungültiger öffentlicher Schlüssel in $key.pub."
        }
        $blob = $Matches[1]
        $install = @'
set -eu
umask 077
mkdir -p .ssh
chmod 700 .ssh
cd .ssh
touch authorized_keys
chmod 600 authorized_keys
present=$(awk -v key="$1" '
    /^[[:space:]]*#/ { next }
    {
        # Quoted option values can contain spaces and escaped quotes.
        gsub(/\\"/, "")
        gsub(/"[^"]*"/, "")
        sub(/[[:space:]]+$/, "")
        if (($1 == "ssh-ed25519" && $2 == key) ||
            ($2 == "ssh-ed25519" && $3 == key)) found = 1
    }
    END { print found + 0 }
' authorized_keys)
if [ "$present" = 0 ]; then
    printf '\nssh-ed25519 %s\n' "$1" >> authorized_keys
fi
# Ignore the trailing CR added by a Windows PowerShell text pipeline.
'@
        Write-MenuText 'Schlüssel übertragen … Serverpasswort erneut eingeben.'
        $OutputEncoding = [Text.UTF8Encoding]::new($false)
        $install.Replace("`r", '') | ssh -T @password @connection "cd ~ && sh -s -- $blob"
        if ($LASTEXITCODE -ne 0) { throw 'Installation fehlgeschlagen. Beim nächsten Versuch wird derselbe Schlüssel verwendet.' }
        Write-MenuText 'Anmeldung mit dem neuen Schlüssel prüfen …'
        if (-not (Test-TargetKey $key $connection $identity)) {
            throw 'Anmeldung mit dem vorgesehenen Schlüssel fehlgeschlagen. Beim nächsten Versuch wird derselbe Schlüssel verwendet.'
        }
        [IO.File]::WriteAllText($ready, $endpoint)
    } finally {
        $lock.Dispose()
    }
}

function Connect-Target($target) {
    Assert-Target $target
    $connection = @('-p', $target.Port, '-l', $target.User, $target.Server)
    $identity = @()
    if ($target.Login -eq 'Passwort') {
        $key = Join-Path $store "ziel-$($target.KeyId).ed25519"
        $endpoint = "$($target.User)@$($target.Server.ToLowerInvariant()):$([int]$target.Port)"
        $identity = @('-o', 'PreferredAuthentications=publickey', '-o', 'IdentitiesOnly=yes', '-i', $key)
        if (-not [IO.File]::Exists("$key.ready") -or [IO.File]::ReadAllText("$key.ready") -cne $endpoint) {
            Install-TargetKey $key $connection $identity $endpoint
        }
        if (-not [IO.File]::Exists($key)) { throw "Privater Schlüssel fehlt: $key" }
    }
    & ssh @identity @connection
    if ($LASTEXITCODE -eq 0) { Write-MenuText 'SSH-Sitzung beendet.' }
    else { Write-MenuText "SSH beendet (Status $LASTEXITCODE). Details stehen in der SSH-Ausgabe." }
}

function Get-UserModuleDirectory {
    if ($env:OS -eq 'Windows_NT') {
        $documents = [Environment]::GetFolderPath('MyDocuments')
        # Das WindowsPowerShell-Verzeichnis wird standardmäßig von beiden Editionen durchsucht.
        $candidates = (Join-Path $documents 'WindowsPowerShell/Modules'), (Join-Path $documents 'PowerShell/Modules')
    } else {
        $data = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { Join-Path $HOME '.local/share' }
        $candidates = @(Join-Path $data 'powershell/Modules')
    }
    $searchPath = ($env:PSModulePath -split [IO.Path]::PathSeparator).TrimEnd([char[]]'\/')
    foreach ($directory in $candidates) {
        if ($directory -in $searchPath) { return $directory }
    }
    throw 'Das PowerShell-Modulverzeichnis deines Benutzerkontos fehlt in PSModulePath.'
}

function Initialize-GlobalCommand {
    $escapedPath = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($script:ManagerScriptPath)
    $launch = "& '$escapedPath'"
    $command = Get-Command SSH-Manager -ErrorAction SilentlyContinue
    if ($command) {
        $resolved = if ($command -is [System.Management.Automation.AliasInfo]) { $command.ResolvedCommand } else { $command }
        if ($resolved.Path -eq $script:ManagerScriptPath -or
            ($resolved.ModuleName -eq 'SSH-Manager' -and $resolved.Definition.Trim() -ceq $launch)) { return }
        Write-Warning (Translate-Text "Der Name SSH-Manager ist durch einen anderen Befehl belegt ($($command.CommandType)). Du kannst dieses Skript weiterhin direkt starten.")
        return
    }

    $root = Get-UserModuleDirectory
    $destination = Join-Path $root 'SSH-Manager'
    $launcher = "function SSH-Manager { $launch }"
    $installed = Join-Path $destination 'SSH-Manager.psm1'
    if ([IO.File]::Exists($installed) -and [IO.File]::ReadAllText($installed) -ceq $launcher) {
        Write-Host (Translate-Text 'Gib zuerst Import-Module SSH-Manager und danach SSH-Manager ein.')
        return
    }
    Write-Host (Translate-Text 'Mit dem Befehl SSH-Manager kannst du dieses Skript aus jedem Ordner starten.')
    $choice = Read-Host (Translate-Text 'Dafür einen Verweis im PowerShell-Modulverzeichnis deines Benutzerkontos anlegen? [j/N]')
    if ($choice -notin 'j', 'ja', 'y', 'yes') { return }

    if ([IO.Directory]::Exists($destination)) { throw "Das Modulverzeichnis ist bereits belegt: $destination" }
    $stage = Join-Path $root ([guid]::NewGuid().ToString())
    $moduleFile = Join-Path $stage 'SSH-Manager.psm1'
    [void][IO.Directory]::CreateDirectory($stage)
    try {
        [IO.File]::WriteAllText($moduleFile, $launcher, [Text.UTF8Encoding]::new($true))
        [IO.Directory]::Move($stage, $destination)
    } finally {
        if ([IO.Directory]::Exists($stage)) {
            [IO.File]::Delete($moduleFile)
            [IO.Directory]::Delete($stage)
        }
    }
    if (-not (Get-Command SSH-Manager -ErrorAction SilentlyContinue)) {
        Write-Host (Translate-Text 'Lade das Modul in jeder neuen Sitzung zuerst mit Import-Module SSH-Manager.')
    }
    Write-Host (Translate-Text 'Gib künftig in PowerShell in einem beliebigen Ordner SSH-Manager ein und drücke Enter.')
    Write-Host (Translate-Text "Der Befehl verweist auf $script:ManagerScriptPath. Lass das Skript an diesem Speicherort.")
}

function Format-TargetAddress($target) {
    $server = [string]$target.Server
    if ($server.Contains(':')) { $server = "[$server]" }
    "$($target.User)@${server}:$([int]$target.Port)"
}

function Show-TargetMenu($targets, $total, $filter, $width) {
    Write-Host ''
    Write-MenuText "SSH-Manager · v$script:ManagerVersion" $width Cyan
    if ($script:AvailableUpdateVersion) {
        $notice = if ($script:Language -eq 'de') {
            "Veraltete Version! Update v$script:AvailableUpdateVersion verfügbar."
        } else {
            "Outdated version! Update v$script:AvailableUpdateVersion available."
        }
        Write-MenuText $notice $width Yellow
    }
    if ($filter) { Write-MenuText ('Suche "{0}" · {1} von {2}' -f $filter, $targets.Count, $total) $width }
    else { Write-MenuText "SSH-Ziele ($total)" $width }
    Write-Host ''

    if ($targets.Count) {
        $numberWidth = [Math]::Max(2, "$($targets.Count)".Length)
        $nameHeading = Translate-Text 'Kurzname'
        $addressHeading = Translate-Text 'Verbindung'
        $loginHeading = Translate-Text 'Anmeldung'
        $nameWidth = $nameHeading.Length
        $addressWidth = $addressHeading.Length
        $rows = for ($i = 0; $i -lt $targets.Count; $i++) {
            $target = $targets[$i]
            $name = [string]$target.Name
            $address = Format-TargetAddress $target
            $nameWidth = [Math]::Max($nameWidth, $name.Length)
            $addressWidth = [Math]::Max($addressWidth, $address.Length)
            [pscustomobject]@{
                Number = [string]($i + 1)
                Name = $name
                Address = $address
                Login = if ($target.Login -eq 'Passwort') { Translate-Text 'Verwaltet' } else { 'OpenSSH' }
                Target = $target
            }
        }
        $numberWidth = [Math]::Max($numberWidth, (Translate-Text 'Nr').Length)
        $tableWidth = $numberWidth + $nameWidth + $addressWidth + $loginHeading.Length + 6
        if ($width -ge 68 -and $tableWidth -le $width) {
            Write-Host ('{0}  {1}  {2}  {3}' -f (Translate-Text 'Nr').PadLeft($numberWidth),
                $nameHeading.PadRight($nameWidth), $addressHeading.PadRight($addressWidth), $loginHeading)
            Write-Host ('─' * $tableWidth)
            foreach ($row in $rows) {
                Write-Host ('{0}  {1}  {2}  {3}' -f $row.Number.PadLeft($numberWidth),
                    $row.Name.PadRight($nameWidth), $row.Address.PadRight($addressWidth), $row.Login)
            }
        } else {
            foreach ($row in $rows) {
                Write-MenuText "$($row.Number)  $($row.Name)" $width Cyan
                $detail = "  $($row.Address)  ·  $($row.Login)"
                if ($detail.Length -le $width) {
                    Write-Host $detail
                    continue
                }
                if ($row.Address.Length + 2 -le $width) {
                    Write-Host "  $($row.Address)"
                } else {
                    Write-MenuText "  $($row.Target.Server)" $width
                    Write-MenuText "  $($row.Target.User) · Port $([int]$row.Target.Port)" $width
                }
                Write-MenuText "  $($row.Login)" $width
            }
        }
        Write-Host ''
    } elseif ($filter) {
        Write-MenuText 'Keine Treffer. Unter Optionen kannst du die Suche ändern oder leeren.' $width
        Write-Host ''
    } else {
        Write-MenuText 'Noch keine Ziele. Unter Optionen kannst du Ziele anlegen oder importieren.' $width
        Write-Host ''
    }
    $actions = '[O] Optionen   [Q] Beenden'
    if ($targets.Count) { $actions = '[Nr] Verbinden   ' + $actions }
    Write-MenuText $actions $width
}

function Read-ManagerOption($width) {
    Write-Host ''
    Write-MenuText 'Optionen' $width Cyan
    Write-MenuText '[N] Neu   [B] Bearbeiten   [L] Löschen' $width
    Write-MenuText '[S] Suchen   [I] Import   [E] Export' $width
    Write-MenuText '[G] Sprache' $width
    Write-MenuText '[Enter] Zurück' $width
    while ($true) {
        $inputText = Read-MenuInput 'Option' $width
        if ($null -eq $inputText) { return }
        $action = $inputText.Trim()
        if ($action -in '', 'N', 'B', 'L', 'S', 'I', 'E', 'G') { return $action }
        Write-MenuText 'Bitte eine angezeigte Option wählen.' $width
    }
}

function Find-Targets($targets, [string]$filter) {
    $terms = @($filter -split '\s+' | Where-Object { $_ })
    foreach ($target in $targets) {
        $method = if ($target.Login -eq 'Passwort') { 'Verwaltet Managed' } else { 'OpenSSH' }
        $text = "$($target.Name) $(Format-TargetAddress $target) $($target.Server) $($target.User) $($target.Port) $($target.Login) $method"
        $matches = $true
        foreach ($term in $terms) {
            if ($text.IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                $matches = $false
                break
            }
        }
        if ($matches) { $target }
    }
}

function Read-LiveSearch($allTargets, [string]$currentFilter) {
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        return Read-MenuInput 'Suche (Enter setzt zurück)'
    }
    $query = $currentFilter
    while ($true) {
        $width = Get-MenuWidth
        try {
            Clear-Host
            $matches = @(Find-Targets $allTargets $query)
            Show-TargetMenu $matches $allTargets.Count $query $width
            Write-MenuText '[Enter] Übernehmen   [Esc] Abbrechen   [Backspace] Löschen' $width
            Write-MenuText "Suchbegriff: $query" $width
            $key = [Console]::ReadKey($true)
        } catch {
            return Read-MenuInput 'Suche (Enter setzt zurück)' $width
        }
        if ($key.Key -eq [ConsoleKey]::Enter) { return $query.Trim() }
        if ($key.Key -eq [ConsoleKey]::Escape) { return $null }
        if ($key.Key -eq [ConsoleKey]::Backspace) {
            if ($query.Length) { $query = $query.Substring(0, $query.Length - 1) }
        } elseif (-not [char]::IsControl($key.KeyChar)) {
            $query += $key.KeyChar
        }
    }
}

function Start-Manager {
    $filter = ''
    $previousWidth = 0
    $refresh = $true
    while ($true) {
        $width = Get-MenuWidth
        if ($refresh -or $width -ne $previousWidth) {
            $allTargets = @(Get-Targets | Sort-Object Name)
            $targets = @(Find-Targets $allTargets $filter)
            Show-TargetMenu $targets $allTargets.Count $filter $width
            $previousWidth = $width
            $refresh = $false
        }
        $inputText = Read-MenuInput 'Auswahl' $width
        if ($null -eq $inputText) { return }
        $choice = $inputText.Trim()
        try {
            if ($choice -eq 'Q') { return }
            if ($choice -eq '') { $refresh = $true; continue }
            $action = ''
            if ($choice -eq 'O') {
                $action = Read-ManagerOption $width
                if ($null -eq $action) { return }
                $refresh = $true
                if ($action -eq '') { continue }
            }
            if ($action -eq 'G') {
                Write-MenuText 'Sprache wählen · [1] Englisch  [2] Deutsch' $width Cyan
                $languageChoice = Read-MenuInput 'Sprache (Enter zurück)' $width
                if ($null -eq $languageChoice) { return }
                if ($languageChoice -in '1', '2') {
                    Set-Language $(if ($languageChoice -eq '1') { 'en' } else { 'de' })
                } elseif ($languageChoice.Trim()) {
                    Write-MenuText 'Bitte 1 oder 2 wählen.' $width
                }
                continue
            }
            if ($action -eq 'N') { Edit-Target; continue }
            if ($action -eq 'S') {
                $query = Read-LiveSearch $allTargets $filter
                if ($null -ne $query) { $filter = ([regex]::Replace($query, '\p{Cc}', '')).Trim() }
                continue
            }
            if ($action -in 'I', 'E') {
                if ($action -eq 'I') { Write-MenuText 'Import · Gleichnamige Ziele werden übersprungen.' $width Cyan }
                else { Write-MenuText 'Export · Alle Ziele ohne SSH-Schlüssel.' $width Cyan }
                $inputPath = Read-MenuInput 'Pfad zur JSON-Datei (Enter zurück)' $width
                if ([string]::IsNullOrWhiteSpace($inputPath)) { continue }
                $path = Resolve-TransferPath $inputPath
                if ($action -eq 'I') {
                    $result = Import-Targets $path
                    Write-MenuText "Import abgeschlossen · $($result.Added) übernommen, $($result.Skipped) übersprungen." $width
                } else {
                    $count = Export-Targets $path
                    Write-MenuText "Export abgeschlossen · $count gespeichert." $width
                }
                continue
            }
            $selection = $choice
            if ($action -in 'B', 'L') {
                if (-not $targets.Count) {
                    Write-MenuText 'Keine Ziele zur Auswahl.' $width
                    continue
                }
                $prompt = if ($action -eq 'B') { 'Bearbeiten · Nr (Enter zurück)' } else { 'Löschen · Nr (Enter zurück)' }
                $selection = Read-MenuInput $prompt $width
                if ($null -eq $selection) { return }
                if ([string]::IsNullOrWhiteSpace($selection)) { continue }
            }
            $index = 0
            if (-not [int]::TryParse($selection, [ref]$index) -or $index -lt 1 -or $index -gt $targets.Count) {
                $hint = if ($action) { 'Bitte eine angezeigte Zielnummer eingeben.' } else { 'Bitte eine angezeigte Zielnummer, O oder Q eingeben.' }
                Write-MenuText $hint $width
                continue
            }
            $target = $targets[$index-1]
            $refresh = $true
            switch ($action) {
                'B' { Edit-Target $target }
                'L' {
                    Write-Host ''
                    Write-MenuText "Ziel löschen · $($target.Name)" $width Cyan
                    Write-MenuText (Format-TargetAddress $target) $width
                    Write-MenuText 'Lokale Schlüssel und Serverfreigaben bleiben erhalten.' $width
                    $confirm = Read-MenuInput 'Ziel löschen? [j/N]' $width
                    if ($confirm -in 'j', 'ja', 'y', 'yes') {
                        Remove-Target $target
                        Write-MenuText "Ziel '$($target.Name)' gelöscht." $width
                    }
                }
                default {
                    Write-Host ''
                    Write-MenuText "Verbinde · $($target.Name)" $width Cyan
                    Write-MenuText (Format-TargetAddress $target) $width
                    Connect-Target $target
                }
            }
        } catch {
            Write-MenuText "Fehler · $($_.Exception.Message)" $width
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Initialize-GlobalCommand } catch { Write-Warning (Translate-Text "Globaler Aufruf: $($_.Exception.Message)") }
    Test-ManagerUpdate
    Start-Manager
}
