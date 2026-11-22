#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$previousModulePath = $env:PSModulePath
$scratch = Join-Path ([IO.Path]::GetTempPath()) ("Manager's Test " + [guid]::NewGuid())
$modules = Join-Path $scratch 'Modules'
$source = Join-Path $scratch 'SSH-Manager.ps1'
$installed = Join-Path $modules 'SSH-Manager/SSH-Manager.psm1'
[void][IO.Directory]::CreateDirectory($scratch)
Push-Location -LiteralPath $scratch
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../SSH-Manager.ps1') -Destination $source
    . $source
    $env:PSModulePath = $modules + [IO.Path]::PathSeparator + (Join-Path $PSHOME 'Modules')
    function Get-UserModuleDirectory { $modules }
    $answers = [Collections.Queue]::new(@('n', 'ja'))
    function Read-Host { $answers.Dequeue() }

    Set-Alias -Name SSH-Manager -Value Get-Date -Scope Local
    Initialize-GlobalCommand
    if ((Get-Command SSH-Manager).Definition -ne 'Get-Date' -or $answers.Count -ne 2) { throw 'Namenskonflikt übergangen.' }
    Remove-Item -LiteralPath Alias:SSH-Manager
    Set-Alias -Name SSHM -Value Get-Date -Scope Local
    Initialize-GlobalCommand
    if ((Get-Command SSHM).Definition -ne 'Get-Date' -or [IO.Directory]::Exists($modules)) {
        throw 'Existing SSHM command was overwritten.'
    }
    Remove-Item -LiteralPath Alias:SSHM
    Initialize-GlobalCommand
    if ([IO.Directory]::Exists($modules)) { throw 'Modul trotz Ablehnung angelegt.' }
    Initialize-GlobalCommand
    Initialize-GlobalCommand
    if (-not [IO.File]::Exists($installed) -or $answers.Count -ne 0 -or
        -not [IO.File]::ReadAllText($installed).Contains('function SSHM')) {
        throw 'Globaler Aufruf oder Kurzaufruf wurde nicht eingerichtet.'
    }
    # Existing users already have the legacy module. Extend it without re-prompting.
    $legacy = ([IO.File]::ReadAllText($installed) -split "`n")[0]
    [IO.File]::WriteAllText($installed, $legacy)
    Initialize-GlobalCommand
    if (-not [IO.File]::ReadAllText($installed).Contains('function SSHM')) {
        throw 'Existing PowerShell module was not upgraded with the SSHM shortcut.'
    }

    # Reproduce the reported bug: an existing PowerShell session has already loaded
    # the original module without SSHM. Running SSH-Manager updates the module file,
    # but must also expose SSHM immediately without restarting PowerShell.
    [IO.File]::WriteAllText($installed, $legacy)
    $existingSession = {
        function Test-Path($LiteralPath) {
            if ($LiteralPath -eq (Join-Path (Join-Path $HOME '.ssh') 'ssh-manager')) { return $false }
            Microsoft.PowerShell.Management\Test-Path @PSBoundParameters
        }
        function Read-Host($Prompt) {
            if ($Prompt -notin 'Auswahl', 'Selection') { exit 15 }
            'Q'
        }
        function Invoke-RestMethod { [pscustomobject]@{ tag_name = 'v0.3.6' } }
        # Autoload the legacy module; it updates its own file when executed.
        SSH-Manager
        if (-not (Get-Command SSHM -ErrorAction SilentlyContinue)) {
            throw 'SSHM was not registered in the current PowerShell session.'
        }
        sshm
        SSHM
    }
    $output = & (Get-Process -Id $PID).Path -NoProfile -Command $existingSession
    if ($LASTEXITCODE -ne 0 -or @($output | Where-Object { $_ -match 'SSH (targets|Ziele)' }).Count -ne 3) {
        throw "Short command unavailable in an already running PowerShell session (exit $LASTEXITCODE; output: $($output -join ' | '))."
    }
    if (-not [IO.File]::ReadAllText($installed).Contains('function SSHM')) {
        throw 'The existing module was not upgraded on disk.'
    }

    # Ohne Profil und außerhalb des Skriptordners muss allein die Zieleauswahl erscheinen.
    Set-Location -LiteralPath $modules
    $check = {
        function Test-Path($LiteralPath) {
            if ($LiteralPath -eq (Join-Path (Join-Path $HOME '.ssh') 'ssh-manager')) { return $false }
            Microsoft.PowerShell.Management\Test-Path @PSBoundParameters
        }
        function Read-Host($Prompt) {
            if ($Prompt -notin 'Auswahl', 'Selection') { exit 12 }
            'Q'
        }
        SSH-Manager
        SSHM
        sshm
    }
    $output = & (Get-Process -Id $PID).Path -NoProfile -Command $check
    if ($LASTEXITCODE -ne 0 -or @($output | Where-Object { $_ -match 'SSH (targets|Ziele)' }).Count -ne 3) {
        throw "Global launcher failed (exit $LASTEXITCODE; output: $($output -join ' | '))."
    }
    # Reproduce updating a script invoked through the global PowerShell command.
    if ($script:ManagerScriptPath -cne $source) { throw 'The script path was lost after dot-sourcing.' }
    $answers = [Collections.Queue]::new(@('y'))
    function Invoke-RestMethod { [pscustomobject]@{ tag_name = 'v0.4.0' } }
    function Invoke-WebRequest {
        param($Uri, $OutFile, $TimeoutSec, [switch]$UseBasicParsing)
        $replacement = [IO.File]::ReadAllText($source).Replace(
            '$script:ManagerVersion = ''0.3.6''', '$script:ManagerVersion = ''0.4.0''')
        [IO.File]::WriteAllText($OutFile, $replacement)
    }
    Test-ManagerUpdate
    $updated = [IO.File]::ReadAllText($source)
    if ($answers.Count -ne 0 -or $script:AvailableUpdateVersion -or
        -not $updated.Contains('$script:ManagerVersion = ''0.4.0''')) {
        throw 'Self-update did not replace the installed script launched through the PowerShell module.'
    }
    Write-Output 'PowerShell self-update path verified.'
    Write-Output 'Globaler Start erfolgreich geprüft.'
} finally {
    Pop-Location
    $env:PSModulePath = $previousModulePath
    [IO.File]::Delete($source)
    if ([IO.File]::Exists($installed)) { [IO.File]::Delete($installed) }
    foreach ($directory in (Split-Path $installed), $modules, $scratch) {
        if ([IO.Directory]::Exists($directory)) { [IO.Directory]::Delete($directory) }
    }
}
