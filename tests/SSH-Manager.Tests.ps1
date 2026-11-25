#requires -Version 5.1
. (Join-Path $PSScriptRoot '../SSH-Manager.ps1')
$script:Language = 'de'

function Assert($condition, $message) {
    if (-not $condition) { throw $message }
}

# Nur die interaktiven Programme ersetzen. Speicherung und Verbindungsablauf laufen wie im Menü.
function ssh {
    $script:calls += ,@($args)
    if ($args[-1] -like 'umask 077; f=*') {
        $script:uploaded = $input -join "`n"
        $global:LASTEXITCODE = 0
        return $uploadReply
    }
    $global:LASTEXITCODE = if ($args -contains '-E') {
            $log = $args[[array]::IndexOf($args, '-E') + 1]
            $lines = @(
                foreach ($signer in $signers) { "debug3: sign_and_send_pubkey: using publickey with ED25519 $signer" }
                if ($authentication) { $authentication }
            )
            [IO.File]::WriteAllLines($log, $lines)
            $verifyExit
        }
        elseif ($args -contains 'exit 0') { $probeExit }
        elseif ($args[-1] -like 'cd ~ && sh -s -- *') {
            $script:installer = $input -join "`n"
            $installExit
        }
        else { 0 }
}
function ssh-keygen {
    if ($args -contains '-l') { $global:LASTEXITCODE = 0; return '256 SHA256:managed test (ED25519)' }
    $script:generated++
    [IO.File]::WriteAllText($args[-1], 'Test')
    [IO.File]::WriteAllText("$($args[-1]).pub", 'ssh-ed25519 QUJD test')
    $global:LASTEXITCODE = 0
}
function Read-Host($prompt) { $answers.Dequeue() }

$store = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$calls = @()
$generated = 0
$probeExit = 255
$installExit = 1
$verifyExit = 255
$signers = @('SHA256:managed')
$authentication = $null
$target = [pscustomobject]@{ Name='Test'; Server='::1'; User='alice'; Port=2222; Login='Passwort' }
try {
    Save-Target $target
    try { Save-Target $target } catch { $duplicateError = $_ }
    Assert ($duplicateError -and @(Get-Targets).Count -eq 1) 'Doppelter Kurzname wurde zugelassen.'
    $saved = @(Get-Targets)[0]
    Assert ($saved.Server -eq '::1' -and $saved.Port -eq 2222) 'Gespeichertes Ziel ist unvollständig.'
    try { Connect-Target $saved } catch { $probeError = $_ }
    Assert ($probeError -and $generated -eq 0 -and $calls.Count -eq 1) 'Schlüssel vor erfolgreicher Anmeldung erstellt.'
    $probeExit = 0
    try { Connect-Target $saved } catch { $installError = $_ }
    Assert ($installError -and $generated -eq 1 -and $calls.Count -eq 3) 'Installationsfehler wurde übergangen.'
    $installExit = 0
    $ready = Join-Path $store "ziel-$($saved.KeyId).ed25519.ready"
    $answers = [Collections.Queue]::new(@('j'))
    try { Connect-Target $saved } catch { $verifyError = $_ }
    Assert ($verifyError -and $answers.Count -eq 0 -and $calls.Count -eq 7 -and
        -not [IO.File]::Exists($ready)) 'Nur nach Zustimmung erneut installieren. Abgelehnten Schlüssel nicht als eingerichtet markieren.'
    $shell = (Get-Command sh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Path
    if (-not $shell -and $env:ProgramFiles) { $shell = Join-Path $env:ProgramFiles 'Git/bin/sh.exe' }
    if ($shell -and [IO.File]::Exists($shell)) {
        Push-Location -LiteralPath $store
        $sshDir = Join-Path $store '.ssh'
        $authorized = Join-Path $sshDir 'authorized_keys'
        try {
            [void][IO.Directory]::CreateDirectory($sshDir)
            $restricted = 'command="echo \"two words\"",no-pty' + "`tssh-ed25519`tQUJD Backup`n"
            [IO.File]::WriteAllText($authorized, $restricted)
            $installer | & $shell -s -- QUJD
            Assert ($LASTEXITCODE -eq 0 -and [IO.File]::ReadAllText($authorized) -ceq $restricted) 'Ein vorhandener eingeschränkter Schlüssel wurde verändert oder dupliziert.'
            $comments = "# ssh-ed25519 QUJD`nssh-ed25519 REVG comment: ssh-ed25519 QUJD"
            [IO.File]::WriteAllText($authorized, $comments)
            1..2 | ForEach-Object {
                $installer | & $shell -s -- QUJD
                Assert ($LASTEXITCODE -eq 0) 'Unix-Installation fehlgeschlagen.'
            }
            Assert ([IO.File]::ReadAllText($authorized) -ceq ($comments + "`nssh-ed25519 QUJD`n")) 'Schlüssel in Kommentaren oder wiederholte Installation fehlerhaft behandelt.'
        } finally {
            Pop-Location
            [IO.File]::Delete($authorized)
            [IO.Directory]::Delete($sshDir)
        }
    } else { Write-Warning 'Unix-Prüfung für authorized_keys übersprungen (sh fehlt).' }
    Assert ($calls[-1] -contains 'ControlPath=none' -and $calls[-1] -contains 'PreferredAuthentications=publickey') 'Prüfung erlaubt eine andere Anmeldung oder eine bestehende Sitzung.'
    $verifyExit = 0
    $authentication = 'Authenticated to ::1 ([::1]:2222) using "publickey".'
    $signers = @('SHA256:managed', 'SHA256:other')
    $answers = [Collections.Queue]::new(@('n'))
    $before = $calls.Count
    try { Connect-Target $saved } catch { $wrongKey = $_ }
    Assert ($wrongKey -and $answers.Count -eq 0 -and $calls.Count -eq ($before + 1) -and
        -not [IO.File]::Exists($ready)) 'Ein anderer Schlüssel wurde als Nachweis akzeptiert oder ohne Zustimmung erneut installiert.'
    $signers = @('SHA256:managed')
    $verifyExit = 1
    Connect-Target $saved
    Assert ([IO.File]::ReadAllText($ready) -ceq 'alice@::1:2222' -and $generated -eq 1) 'Ein erzwungener Befehl mit Fehlerstatus darf eine erfolgreiche Schlüsselanmeldung nicht entwerten.'
    $before = $calls.Count
    Connect-Target $saved
    Assert ($calls.Count -eq ($before + 1) -and $calls[-1] -contains '-i' -and $calls[-1] -contains 'PreferredAuthentications=publickey') 'Folgeverbindung verwendet den Schlüssel nicht.'
    [IO.File]::WriteAllText($ready, 'verified')
    $verifyExit = 0
    $authentication = $null
    $answers = [Collections.Queue]::new(@(''))
    $before = $calls.Count
    try { Connect-Target $saved } catch { $repairError = $_ }
    Assert ($repairError -and $answers.Count -eq 0 -and $calls.Count -eq ($before + 1) -and
        [IO.File]::ReadAllText($ready) -ceq 'verified') 'Die alte Markierung oder ein Statuscode ohne Anmeldung darf keine Freigabe auslösen.'
    [IO.File]::WriteAllText($ready, '')
    $authentication = 'debug1: Authentication succeeded (publickey).'
    Connect-Target $saved
    Assert ($calls[-2] -contains '-E' -and [IO.File]::ReadAllText($ready) -ceq 'alice@::1:2222') 'Alter Einrichtungsstatus wurde nicht geprüft.'
    $target.Name = 'Zweitserver'
    $target.Login = 'Schlüssel'
    Save-Target $target
    Connect-Target $target
    Assert (@(Get-Targets).Count -eq 2 -and ($calls[-1] -join ' ') -eq '-p 2222 -l alice ::1') 'Vorhandener Schlüssel muss die OpenSSH-Konfiguration einschließlich MFA verwenden.'
    $before = $calls.Count
    $target.Server = '-oProxyCommand=ungültig'
    try { Connect-Target $target } catch { $validationError = $_ }
    Assert ($validationError -and $calls.Count -eq $before) 'Ungültiger Host wurde an SSH weitergegeben.'

    # Profil und Schlüssel aus der ersten Version.
    $legacyPath = Join-Path $store 'ziel-alt.json'
    [IO.File]::WriteAllText($legacyPath, '{"Name":"Alt","Server":"host","User":"alice","Port":"22","Login":"Passwort"}')
    $legacy = Get-Targets | Where-Object Name -eq Alt
    Connect-Target $legacy
    $legacyKey = Join-Path $store 'ziel-alt.ed25519'
    Assert ($calls[-1] -contains $legacyKey) 'Bestehender Schlüsselpfad wurde nicht übernommen.'

    $screen = [Collections.Generic.List[string]]::new()
    $menuWidth = 80
    function Write-Host([string]$Object, $ForegroundColor) { $screen.Add($Object) }
    function Get-MenuWidth { $menuWidth }
    $before = $calls.Count
    $answers = [Collections.Queue]::new(@('O','R','Q'))
    Start-Manager
    Assert ($screen -contains 'Keine .sh-Dateien in user/ oder root/.' -and $calls.Count -eq $before) 'Empty script folders started SSH.'
    $uploadReply = '/tmp/ssh-manager.a123456789'
    foreach ($role in 'user', 'root') {
        [IO.File]::WriteAllText((Join-Path $store "scripts/$role/status check.sh"), "echo Grüße-$role")
    }
    $answers = [Collections.Queue]::new(@('O','S','Zweit','O','R','','O','R','3','O','R','1','','Q'))
    Start-Manager
    Assert ($calls.Count -eq $before) 'Cancelling or selecting an invalid script started SSH.'
    foreach ($choice in '1','2') {
        $role = if ($choice -eq '1') { 'user' } else { 'root' }
        $answers = [Collections.Queue]::new(@('O','S','Zweit','O','R',$choice,'1','Q'))
        Start-Manager
        $run = $calls[-1]
        Assert ($uploaded -ceq "echo Grüße-$role" -and $calls[-2] -ccontains '-T' -and $run -ccontains '-t' -and
            ($run -join ' ') -like '*-p 2222 -l alice ::1 *' -and $run[-1].Contains("bash $uploadReply") -and
            $run[-1].Contains('sudo -u root --') -eq ($role -eq 'root')) "Incorrect script, target or permissions for $role."
    }
    $uploadReply = '/tmp/unexpected; exit 0'
    $before = $calls.Count
    $answers = [Collections.Queue]::new(@('O','S','Zweit','O','R','1','1','Q'))
    Start-Manager
    Assert ($calls.Count -eq $before + 1 -and $screen -contains 'Fehler · Skriptübertragung fehlgeschlagen.') 'Invalid upload response reached the execution step.'
    $screen.Clear()
    $answers = [Collections.Queue]::new(@('O','B','1','Archiv','','','','','O','L','1','n','Q'))
    Start-Manager
    $edited = Get-Targets | Where-Object Name -eq Archiv
    Assert ($edited.User -ceq 'alice' -and $edited.Server -eq 'host' -and $edited.Port -eq 22) 'Enter muss die Feldwerte beibehalten.'
    Assert (($screen -join "`n") -match 'Nr\s+Kurzname\s+Verbindung\s+Anmeldung' -and
        ($screen -join "`n") -match '1\s+Archiv\s+alice@host:22') 'Tabellenkopf oder Nummerierung fehlt.'
    Connect-Target $edited
    Assert ($calls[-1] -contains $legacyKey -and $generated -eq 2) 'Nach dem Umbenennen fehlt der bisherige Schlüssel.'
    try { Remove-Target $legacy } catch { $staleError = $_ }
    Assert ($staleError -and [IO.File]::Exists($legacyPath)) 'Veraltete Auswahl hat ein geändertes Ziel gelöscht.'

    $answers = [Collections.Queue]::new(@('O','B','1','','','','2222','','','Q'))
    Start-Manager
    $edited = Get-Targets | Where-Object Name -eq Archiv
    $authentication = $null
    $answers = [Collections.Queue]::new(@('n'))
    $before = $calls.Count
    try { Connect-Target $edited } catch { $portError = $_ }
    Assert ($portError -and $answers.Count -eq 0 -and $calls.Count -eq ($before + 1) -and $calls[-1] -contains '-E' -and
        $calls[-1] -contains '2222' -and [IO.File]::ReadAllText("$legacyKey.ready") -ceq 'alice@host:22') 'Ein neuer Port muss vor der Nutzung geprüft werden.'
    $authentication = 'Authenticated to host (via proxy) using "publickey".'
    $before = $calls.Count
    Connect-Target $edited
    Assert ($calls.Count -eq ($before + 2) -and $calls[-2] -contains '-E' -and $calls[-1] -contains $legacyKey -and
        $calls[-1] -contains '2222' -and [IO.File]::ReadAllText("$legacyKey.ready") -ceq 'alice@host:2222') 'Portwechsel muss denselben Schlüssel für den neuen Dienst bestätigen.'
    $answers = [Collections.Queue]::new(@('O','B','1','','','','2223','','n','Q'))
    Start-Manager
    $edited = Get-Targets | Where-Object Name -eq Archiv
    Assert ($edited.KeyId -ne $legacy.KeyId) 'Neuer Dienst am anderen Port hat den alten Schlüssel übernommen.'

    $screen.Clear()
    $answers = [Collections.Queue]::new(@('O','B','1','Test','!','Q'))
    Start-Manager
    Assert ($screen -contains 'Dieser Kurzname ist bereits vergeben.' -and $screen -contains 'Bearbeitung abgebrochen.' -and
        (Get-Targets | Where-Object Name -eq Archiv).Snapshot -ceq $edited.Snapshot) 'Namenskollision oder Abbruch hat das Profil überschrieben.'
    $previousKeyId = $edited.KeyId
    $answers = [Collections.Queue]::new(@('O','B','1','','host2','bob','2223','2','Q'))
    Start-Manager
    $edited = Get-Targets | Where-Object Name -eq Archiv
    Assert ($edited.User -ceq 'bob' -and $edited.Server -eq 'host2' -and $edited.Port -eq 2223 -and $edited.Login -eq 'Schlüssel') 'Bearbeitete Verbindungsdaten wurden nicht gespeichert.'
    Assert ($edited.KeyId -ne $previousKeyId) 'Geändertes Verbindungsziel übernimmt den alten Einrichtungsstatus.'

    $answers = [Collections.Queue]::new(@('O','L','1','j','O','N','Alt','neu','alice','','','Q'))
    Start-Manager
    $new = Get-Targets | Where-Object Name -eq Alt
    Assert ($new -and $new.KeyId -ne $legacy.KeyId -and [IO.File]::Exists($legacyKey)) 'Wiederverwendeter Kurzname gefährdet den alten Schlüssel.'
    Assert (-not (Get-Targets | Where-Object Name -eq Archiv) -and @(Get-Targets).Count -eq 3) 'Löschen hat die falschen Ziele verändert.'

    $visibleTargets = @(Get-Targets | Sort-Object Name)
    Assert (@(Find-Targets $visibleTargets 'MANAGED 2222').Count -eq 1 -and
        @(Find-Targets $visibleTargets 'OpenSSH Zweit').Count -eq 1 -and
        @(Find-Targets $visibleTargets 'alice neu').Count -eq 1 -and
        @(Find-Targets $visibleTargets 'missing').Count -eq 0 -and
        @(Find-Targets $visibleTargets '').Count -eq $visibleTargets.Count) 'Full-text search must match all words across target fields and clear correctly.'
    foreach ($width in 24, 40, 67, 68, 104) {
        $screen.Clear()
        Show-TargetMenu $visibleTargets $visibleTargets.Count '' $width
        $hasTable = ($screen -join "`n") -match 'Nr\s+Kurzname\s+Verbindung\s+Anmeldung'
        Assert ($hasTable -eq ($width -ge 68) -and
            -not @($screen | Where-Object Length -gt $width).Count -and
            ($screen -join ' ') -match '\[Nr\]\s+Verbinden.*\[O\]\s+Optionen.*\[Q\]\s+Beenden' -and
            ($screen -join ' ') -notmatch '\[[NBSLIE]\]' -and
            ($screen -join "`n") -match 'alice@\[::1\]:2222') "Darstellung bei $width Spalten verliert Daten oder überschreitet die Breite."
    }
    $longName = 'build-' + ('a' * 58)
    $longHost = ('b' * 62) + '.' + ('c' * 62) + '.example.org'
    $longTarget = [pscustomobject]@{ Name=$longName; Server=$longHost; User='alice'; Port=22; Login='Schlüssel' }
    foreach ($width in 24, 104) {
        $screen.Clear()
        Show-TargetMenu @($longTarget) 1 '' $width
        Assert (-not @($screen | Where-Object Length -gt $width).Count -and
            ($screen -join '').Contains($longName) -and ($screen -join '').Contains($longHost) -and
            ($screen -join ' ') -match 'alice · Port 22') "Lange Profilwerte werden bei $width Spalten abgeschnitten."
    }

    $screen.Clear()
    $menuWidth = 32
    $before = $calls.Count
    $answers = [Collections.Queue]::new(@('O','S','unbekannt','9','O','S','zWeIt','1','O','S','','Q'))
    Start-Manager
    Assert (($screen -join ' ') -match 'Keine Treffer\.' -and ($screen -join ' ') -match '1 von 3' -and
        $screen[-1] -match '\[Q\]' -and @($screen | Where-Object { $_ -eq 'SSH-Ziele (3)' }).Count -eq 2 -and
        $screen -contains 'SSH-Sitzung beendet.' -and
        $calls.Count -eq ($before + 1) -and ($calls[-1] -join ' ') -eq '-p 2222 -l alice ::1') 'Suche, Zurücksetzen oder Verbinden aus der Trefferliste fehlerhaft.'

    $screen.Clear()
    $answers = [Collections.Queue]::new(@('O','N','!','O','N',' Stage ','falsche adresse','stage.example.org','alice','0','2200','3','2','Q'))
    Start-Manager
    $stage = Get-Targets | Where-Object Name -eq Stage
    Assert ($stage.Server -eq 'stage.example.org' -and $stage.Port -eq 2200 -and $stage.Login -eq 'Schlüssel' -and
        ($screen -join ' ') -match 'Port zwischen 1 und 65535' -and @(Get-Targets).Count -eq 4) 'Fehlerhafte Felder müssen einzeln korrigierbar sein. Abbruch darf kein Profil speichern.'

    $screen.Clear()
    $menuWidth = 80
    $answers = [Collections.Queue]::new(@('?','Q'))
    function Read-Host($prompt) {
        $script:menuWidth = 24
        $answers.Dequeue()
    }
    Start-Manager
    Assert (@($screen | Where-Object { $_ -eq 'SSH-Ziele (4)' }).Count -eq 2 -and
        $screen -contains '1  Alt') 'Breitenänderungen müssen das Layout beim nächsten Menüaufruf aktualisieren.'

    function Read-Host($prompt) { $answers.Dequeue() }
    $screen.Clear()
    $before = $calls.Count
    $answers = [Collections.Queue]::new(@('N','o','1','','Q'))
    Start-Manager
    $menuText = $screen -join ' '
    Assert ($answers.Count -eq 0 -and $calls.Count -eq $before -and
        $menuText -match 'Zielnummer, O oder Q' -and $menuText -match '\[Enter\]\s+Zurück' -and
        $menuText -match 'Bitte eine angezeigte Option wählen' -and
        @($screen | Where-Object { $_ -eq 'SSH-Ziele (4)' }).Count -eq 2 -and
        -not @($screen | Where-Object Length -gt 24).Count) 'Optionen und Direktverbindung müssen auch im schmalen Menü getrennt bedienbar sein.'

    $menuWidth = 80
    $screen.Clear()
    $exportPath = Join-Path $store 'Meine Ziele.json'
    Push-Location -LiteralPath $store
    try {
        $answers = [Collections.Queue]::new(@('O','S','stage','O','E','"Meine Ziele.json"','O','E','Meine Ziele.json','Q'))
        Start-Manager
    } finally {
        Pop-Location
    }
    $document = Get-Content -LiteralPath $exportPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert ($document.Version -eq 1 -and $document.Targets.Count -eq 4 -and
        $screen -contains 'Export abgeschlossen · 4 gespeichert.' -and
        ($screen -join ' ') -match 'Datei existiert bereits') 'Export muss alle Ziele erfassen und vorhandene Dateien schützen.'
    foreach ($profile in $document.Targets) {
        Assert (($profile.PSObject.Properties.Name -join ',') -ceq 'Name,Server,User,Port,Login') 'Export enthält interne Felder oder Schlüsseldaten.'
    }
    $testProfile = Get-Targets | Where-Object Name -eq Test
    $stageBefore = (Get-Targets | Where-Object Name -eq Stage).Snapshot
    $exportedTest = $document.Targets | Where-Object Name -eq Test
    $exportedTest | Add-Member KeyId $testProfile.KeyId
    $exportedTest | Add-Member Key 'ignored-key-data'
    $exportedTest | Add-Member Password 'ignored-password'
    $exportedTest | Add-Member FilePath $testProfile.FilePath
    $document.Targets += [pscustomobject]@{ Name='tEsT'; Server='other.example.org'; User='alex'; Port=22; Login='Schlüssel' }
    $importPath = Join-Path $store 'Import.json'
    [IO.File]::WriteAllText($importPath, ($document | ConvertTo-Json -Depth 4))
    Remove-Target $testProfile
    $before = $calls.Count
    $answers = [Collections.Queue]::new(@('O','I',$importPath,'O','I',$exportPath,'Q'))
    Start-Manager
    $importedTest = Get-Targets | Where-Object Name -eq Test
    $importedJson = $importedTest.Snapshot | ConvertFrom-Json
    Assert ($screen -contains 'Import abgeschlossen · 1 übernommen, 4 übersprungen.' -and
        $screen -contains 'Import abgeschlossen · 0 übernommen, 4 übersprungen.' -and
        $importedTest.Server -ceq $testProfile.Server -and $importedTest.User -ceq $testProfile.User -and
        $importedTest.Port -eq $testProfile.Port -and $importedTest.Login -ceq 'Passwort' -and $importedTest.KeyId -cne $testProfile.KeyId -and
        ($importedJson.PSObject.Properties.Name -join ',') -ceq 'Name,Server,User,Port,Login,KeyId' -and
        [IO.File]::Exists((Join-Path $store "ziel-$($testProfile.KeyId).ed25519")) -and
        -not [IO.File]::Exists((Join-Path $store "ziel-$($importedTest.KeyId).ed25519")) -and
        (Get-Targets | Where-Object Name -eq Stage).Snapshot -ceq $stageBefore -and $calls.Count -eq $before) 'Import muss Duplikate und fremde Schlüsseldaten überspringen.'

    $document.Targets = @(
        [pscustomobject]@{ Name='Valid'; Server='valid.example.org'; User='alex'; Port=22; Login='Schlüssel' }
        [pscustomobject]@{ Name='Invalid'; Server='-invalid'; User='alex'; Port=22; Login='Schlüssel' }
    )
    [IO.File]::WriteAllText($importPath, ($document | ConvertTo-Json -Depth 4))
    $answers = [Collections.Queue]::new(@('O','I',$importPath,'Q'))
    Start-Manager
    Assert (($screen -join ' ') -match 'Eintrag 2' -and @(Get-Targets).Count -eq 4) 'Ungültige Profile müssen den Import vor dem ersten Schreiben stoppen.'

    Get-Targets | ForEach-Object { Remove-Target $_ }
    $emptyExport = Join-Path $store 'Leer.json'
    Assert ((Export-Targets $emptyExport) -eq 0 -and (Import-Targets $emptyExport).Added -eq 0) 'Leere Exportdatei muss importierbar sein.'
    $document.Targets = @($document.Targets[0])
    [IO.File]::WriteAllText($importPath, ($document | ConvertTo-Json -Depth 4))
    $singleExport = Join-Path $store 'Einzeln.json'
    Assert ((Import-Targets $importPath).Added -eq 1 -and (Export-Targets $singleExport) -eq 1 -and
        (Import-Targets $singleExport).Skipped -eq 1) 'Exportdatei mit einem Ziel muss importierbar sein.'
    # Check the default English presentation, both language choices, and stable profile data.
    $script:Language = 'en'
    Assert ((Translate-Text 'Optionen') -ceq 'Options' -and
        (Translate-Text '[O] Optionen   [Q] Beenden') -ceq '[O] Options   [Q] Quit' -and
        (Translate-Text "Ziel 'Test' gespeichert.") -ceq "Target 'Test' saved.") 'English text was not translated.'
    $screen.Clear()
    $answers = [Collections.Queue]::new(@('O','G','2','O','G','1','Q'))
    Start-Manager
    Assert ($script:Language -eq 'en' -and $screen -contains 'Choose language · [1] English  [2] German' -and
        $screen -contains 'Sprache wählen · [1] Englisch  [2] Deutsch' -and
        [IO.File]::ReadAllText((Join-Path $store 'language')) -ceq 'en') 'Language switching failed.'
    $script:Language = 'de'
    # Latest release check: ask only when a newer stable version exists.
    function Invoke-RestMethod { [pscustomobject]@{ tag_name = $script:fakeRelease } }
    $script:fakeRelease = 'v0.4.1'
    $answers = [Collections.Queue]::new(@('n'))
    Test-ManagerUpdate
    Assert ($answers.Count -eq 0 -and $script:AvailableUpdateVersion -eq '0.4.1') 'Declining an update must keep the outdated status.'
    $screen.Clear()
    Show-TargetMenu @(Get-Targets) @(Get-Targets).Count '' 40
    Assert (($screen -join ' ') -match 'SSH-Manager · v0.4.0' -and ($screen -join ' ') -match 'Veraltete Version! Update v0.4.1 verfügbar') 'Version and outdated notice missing in German menu.'
    $script:Language = 'en'
    $screen.Clear()
    Show-TargetMenu @(Get-Targets) @(Get-Targets).Count '' 40
    Assert (($screen -join ' ') -match 'Outdated version! Update v0.4.1 available') 'Outdated notice missing in English menu.'
    $script:Language = 'de'
    $script:fakeRelease = 'v0.4.0'
    $answers = [Collections.Queue]::new(@('n'))
    Test-ManagerUpdate
    Assert ($answers.Count -eq 1 -and -not $script:AvailableUpdateVersion) 'The current release prompted for installation or showed as outdated.'
    $script:fakeRelease = 'preview'
    Test-ManagerUpdate
    Assert ($answers.Count -eq 1 -and -not $script:AvailableUpdateVersion) 'Invalid release tag prompted or marked outdated.'
    $setting = Join-Path $store 'auto-update'
    Assert ((Get-AutoUpdateEnabled) -and -not [IO.File]::Exists($setting)) 'Auto-update should default to on.'
    $script:fakeRelease = 'v0.4.1'
    $answers = [Collections.Queue]::new(@('O','A','Q'))
    Start-Manager
    Assert (-not (Get-AutoUpdateEnabled) -and [IO.File]::ReadAllText($setting) -ceq 'off') 'Disabling automatic updates was not saved.'
    $screen.Clear()
    $answers = [Collections.Queue]::new(@('O','U','n','Q'))
    Start-Manager
    Assert ($answers.Count -eq 0 -and $script:AvailableUpdateVersion -eq '0.4.1' -and
        ($screen -join ' ') -match 'Update v0.4.1 verfügbar') 'Manual update check was blocked while auto updates were disabled.'
    $script:fakeRelease = 'v0.4.0'
    $screen.Clear()
    $answers = [Collections.Queue]::new(@('O','U','Q'))
    Start-Manager
    Assert ($screen -contains 'Keine neue Version verfügbar.' -and $answers.Count -eq 0) 'Manual check must report when the installed version is current.'
    $answers = [Collections.Queue]::new(@('O','A','Q'))
    Start-Manager
    Assert ((Get-AutoUpdateEnabled) -and [IO.File]::ReadAllText($setting) -ceq 'on') 'Re-enabling automatic updates failed.'
    Write-Output 'Alle Tests bestanden.'
} finally {
    foreach ($role in 'user', 'root') {
        $dir = Join-Path $store "scripts/$role"
        if ([IO.Directory]::Exists($dir)) {
            [IO.File]::Delete((Join-Path $dir 'status check.sh'))
            [IO.Directory]::Delete($dir)
        }
    }
    $dir = Join-Path $store 'scripts'
    if ([IO.Directory]::Exists($dir)) { [IO.Directory]::Delete($dir) }
    foreach ($file in [IO.Directory]::GetFiles($store)) { [IO.File]::Delete($file) }
    [IO.Directory]::Delete($store)
}
