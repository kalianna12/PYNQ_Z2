$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot

Push-Location $Root
try {
    & "G:\VIVADO2022\Vivado\2022.1\bin\vivado.bat" -mode batch -source "$Root\vivado\build.tcl"
    $BuildCode = $LASTEXITCODE
} finally {
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\Generate-VivadoOverlayReport.ps1"
    Pop-Location
}

exit $BuildCode
