$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$env:DEBUG = ""

Push-Location $Root
try {
    & "G:\Xilinx\Vivado\2018.2\bin\vivado_hls.bat" -f "$Root\hls\hls.tcl"
    $HlsCode = $LASTEXITCODE

    & "G:\Xilinx\Vivado\2018.2\bin\vivado.bat" `
        -mode batch `
        -source "$Root\rtl\sim_led_ctrl.tcl" `
        -journal "$Root\rtl\sim\led_ctrl_axi_sim.jou" `
        -log "$Root\rtl\sim\led_ctrl_axi_sim.log"
    $RtlSimCode = $LASTEXITCODE

    & "G:\Xilinx\Vivado\2018.2\bin\vivado.bat" `
        -mode batch `
        -source "$Root\rtl\sim_ad9226_capture.tcl" `
        -journal "$Root\rtl\sim\ad9226_capture_sim.jou" `
        -log "$Root\rtl\sim\ad9226_capture_sim.log"
    $AdcRtlSimCode = $LASTEXITCODE

    if ($HlsCode -ne 0) {
        $BuildCode = $HlsCode
    } elseif ($RtlSimCode -ne 0) {
        $BuildCode = $RtlSimCode
    } else {
        $BuildCode = $AdcRtlSimCode
    }
} finally {
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\Generate-HlsReport.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\Generate-RtlReport.ps1"
    Pop-Location
}

exit $BuildCode
