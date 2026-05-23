$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$env:DEBUG = ""

Push-Location $Root
try {
    & "G:\Xilinx\Vivado\2018.2\bin\vivado_hls.bat" -f "$Root\hls\hls.tcl"
    $BuildCode = $LASTEXITCODE
} finally {
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\Generate-HlsReport.ps1"
    Pop-Location
}

exit $BuildCode

