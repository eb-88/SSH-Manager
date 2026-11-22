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
    Initialize-GlobalCommand
    if ([IO.Directory]::Exists($modules)) { throw 'Modul trotz Ablehnung angelegt.' }
    Initialize-GlobalCommand
    Initialize-GlobalCommand
    if (-not [IO.File]::Exists($installed) -or $answers.Count -ne 0) { throw 'Globaler Aufruf wurde nicht eingerichtet.' }

    # Ohne Profil und außerhalb des Skriptordners muss allein die Zieleauswahl erscheinen.
    Set-Location -LiteralPath $modules
    $check = {
        function Test-Path($LiteralPath) {
            if ($LiteralPath -eq (Join-Path (Join-Path $HOME '.ssh') 'ssh-manager')) { return $false }
            Microsoft.PowerShell.Management\Test-Path @PSBoundParameters
        }
        function Read-Host($Prompt) {
            if ($Prompt -ne 'Auswahl') { exit 12 }
            'Q'
        }
        SSH-Manager
    }
    $output = & (Get-Process -Id $PID).Path -NoProfile -Command $check
    if ($LASTEXITCODE -ne 0 -or ($output -join ' ') -notmatch 'SSH-Ziele') { throw 'Start in einer neuen PowerShell fehlgeschlagen.' }
    # Simulate the startup updater through the global launcher. The script path must
    # remain the copied installation path even when the updater runs from a function.
    if ($script:ManagerScriptPath -cne $source) { throw 'The installed script path was lost after dot-sourcing.' }
    $answers = [Collections.Queue]::new(@('y'))
    function Invoke-RestMethod { [pscustomobject]@{ tag_name = 'v0.4.0' } }
    function Invoke-WebRequest {
        param($Uri, $OutFile, $TimeoutSec, [switch]$UseBasicParsing)
        $replacement = [IO.File]::ReadAllText($source).Replace(
            '$script:ManagerVersion = ''0.3.3''', '$script:ManagerVersion = ''0.4.0''')
        [IO.File]::WriteAllText($OutFile, $replacement)
    }
    Test-ManagerUpdate
    if ($answers.Count -ne 0 -or $script:AvailableUpdateVersion -or
        [IO.File]::ReadAllText($source) -cnotmatch '(?m)^\$script:ManagerVersion = ''0\.4\.0''
} finally {
    Pop-Location
    $env:PSModulePath = $previousModulePath
    [IO.File]::Delete($source)
    if ([IO.File]::Exists($installed)) { [IO.File]::Delete($installed) }
    foreach ($directory in (Split-Path $installed), $modules, $scratch) {
        if ([IO.Directory]::Exists($directory)) { [IO.Directory]::Delete($directory) }
    }
}
) {
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
