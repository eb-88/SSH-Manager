#requires -Version 5.1
$ErrorActionPreference = 'Stop'

$checkout = Join-Path $HOME 'SSH-Manager'
$script = Join-Path $checkout 'SSH-Manager.ps1'

if (Test-Path -LiteralPath $checkout) {
    if (-not (Test-Path -LiteralPath (Join-Path $checkout '.git') -PathType Container)) {
        throw "Installation directory exists but is not an SSH Manager Git checkout: $checkout"
    }
    $answer = Read-Host 'SSH Manager is already installed. Update it? [y/N]'
    if ($answer -notin 'y', 'yes', 'j', 'ja') {
        Write-Host 'Existing installation was not changed.'
        return
    }
    & git -C $checkout pull --ff-only
} else {
    & git clone --depth 1 'https://github.com/eb-88/SSH-Manager.git' $checkout
}
if ($LASTEXITCODE -ne 0) { throw 'SSH Manager installation/update failed.' }
& $script
