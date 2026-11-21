#requires -Version 5.1

$ErrorActionPreference = 'Stop'
$store = Join-Path (Join-Path $HOME '.ssh') 'ssh-manager'

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
                Write-Warning "$($file.Name): $($_.Exception.Message)"
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
        $answer = Read-Field 'Schlüssel am neuen Port behalten? (j/n)' 'j' -choices @('j', 'n', 'ja', 'nein')
        if ($null -eq $answer) { return }
        $keepKey = $answer -in 'j', 'ja'
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
            if ($answer -notin 'j', 'ja') { throw 'Erneute Schlüsselfreigabe abgebrochen.' }
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
    $escapedPath = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($PSCommandPath)
    $launch = "& '$escapedPath'"
    $command = Get-Command SSH-Manager -ErrorAction SilentlyContinue
    if ($command) {
        $resolved = if ($command -is [System.Management.Automation.AliasInfo]) { $command.ResolvedCommand } else { $command }
        if ($resolved.Path -eq $PSCommandPath -or
            ($resolved.ModuleName -eq 'SSH-Manager' -and $resolved.Definition.Trim() -ceq $launch)) { return }
        Write-Warning "Der Name SSH-Manager ist durch einen anderen Befehl belegt ($($command.CommandType)). Du kannst dieses Skript weiterhin direkt starten."
        return
    }

    $root = Get-UserModuleDirectory
    $destination = Join-Path $root 'SSH-Manager'
    $launcher = "function SSH-Manager { $launch }"
    $installed = Join-Path $destination 'SSH-Manager.psm1'
    if ([IO.File]::Exists($installed) -and [IO.File]::ReadAllText($installed) -ceq $launcher) {
        Write-Host 'Gib zuerst Import-Module SSH-Manager und danach SSH-Manager ein.'
        return
    }
    Write-Host 'Mit dem Befehl SSH-Manager kannst du dieses Skript aus jedem Ordner starten.'
    $choice = Read-Host 'Dafür einen Verweis im PowerShell-Modulverzeichnis deines Benutzerkontos anlegen? [j/N]'
    if ($choice -notin 'j', 'ja') { return }

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
        Write-Host 'Lade das Modul in jeder neuen Sitzung zuerst mit Import-Module SSH-Manager.'
    }
    Write-Host 'Gib künftig in PowerShell in einem beliebigen Ordner SSH-Manager ein und drücke Enter.'
    Write-Host "Der Befehl verweist auf $PSCommandPath. Lass das Skript an diesem Speicherort."
}

function Format-TargetAddress($target) {
    $server = [string]$target.Server
    if ($server.Contains(':')) { $server = "[$server]" }
    "$($target.User)@${server}:$([int]$target.Port)"
}

function Show-TargetMenu($targets, $total, $filter, $width) {
    Write-Host ''
    Write-MenuText 'SSH-Manager' $width Cyan
    if ($filter) { Write-MenuText ('Suche "{0}" · {1} von {2}' -f $filter, $targets.Count, $total) $width }
    else { Write-MenuText "SSH-Ziele ($total)" $width }
    Write-Host ''

    if ($targets.Count) {
        $numberWidth = [Math]::Max(2, "$($targets.Count)".Length)
        $nameWidth = 'Kurzname'.Length
        $addressWidth = 'Verbindung'.Length
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
                Login = if ($target.Login -eq 'Passwort') { 'Verwaltet' } else { 'OpenSSH' }
                Target = $target
            }
        }
        $tableWidth = $numberWidth + $nameWidth + $addressWidth + 'Anmeldung'.Length + 6
        if ($width -ge 68 -and $tableWidth -le $width) {
            Write-Host ('{0}  {1}  {2}  Anmeldung' -f 'Nr'.PadLeft($numberWidth),
                'Kurzname'.PadRight($nameWidth), 'Verbindung'.PadRight($addressWidth))
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
    $actions = '[O] Optionen   [Q] Beenden'
    if ($targets.Count) { $actions = '[Nr] Verbinden   ' + $actions }
    Write-MenuText $actions $width
}

function Read-ManagerOption($width) {
    Write-Host ''
    Write-MenuText 'Optionen' $width Cyan
    Write-MenuText '[N] Neu   [B] Bearbeiten   [L] Löschen' $width
    Write-MenuText '[S] Suchen   [I] Import   [E] Export' $width
    Write-MenuText '[Enter] Zurück' $width
    while ($true) {
        $inputText = Read-MenuInput 'Option' $width
        if ($null -eq $inputText) { return }
        $action = $inputText.Trim()
        if ($action -in '', 'N', 'B', 'L', 'S', 'I', 'E') { return $action }
        Write-MenuText 'Bitte eine angezeigte Option wählen.' $width
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
            $targets = $allTargets
            if ($filter) {
                $targets = @($allTargets | Where-Object {
                    "$($_.Name) $(Format-TargetAddress $_)".IndexOf($filter, [StringComparison]::OrdinalIgnoreCase) -ge 0
                })
            }
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
            if ($action -eq 'N') { Edit-Target; continue }
            if ($action -eq 'S') {
                $query = Read-MenuInput 'Suche (Enter setzt zurück)' $width
                if ($null -eq $query) { return }
                $filter = ([regex]::Replace($query, '\p{Cc}', '')).Trim()
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
                    if ($confirm -in 'j', 'ja') {
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
    try { Initialize-GlobalCommand } catch { Write-Warning "Globaler Aufruf: $($_.Exception.Message)" }
    Start-Manager
}
