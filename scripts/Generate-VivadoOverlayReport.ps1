$ErrorActionPreference = "SilentlyContinue"

$Root = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $Root "VIVADO_OVERLAY_REPORT.md"
$VivadoLog = Join-Path $Root "vivado.log"
$TimingRpt = Join-Path $Root "build\vivado\base_add_overlay.runs\impl_1\system_wrapper_timing_summary_routed.rpt"
$UtilRpt = Join-Path $Root "build\vivado\base_add_overlay.runs\impl_1\system_wrapper_utilization_placed.rpt"
$PynqDir = Join-Path $Root "pynq"
$BitFile = Join-Path $Root "pynq\base_add.bit"
$HwhFile = Join-Path $Root "pynq\base_add.hwh"
$XprFile = Join-Path $Root "build\vivado\base_add_overlay.xpr"

function Read-AllTextSafe($Path) {
    if (Test-Path $Path) { return [System.IO.File]::ReadAllText($Path) }
    return ""
}

function File-Line($Path, $Pattern) {
    if (!(Test-Path $Path)) { return "" }
    $m = Select-String -Path $Path -Pattern $Pattern | Select-Object -First 1
    if ($m) { return $m.Line.Trim() }
    return ""
}

function File-InfoLine($Path) {
    if (!(Test-Path $Path)) { return "| $Path | MISSING | - | - |" }
    $f = Get-Item $Path
    return "| $($f.Name) | FOUND | $($f.Length) | $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) |"
}

function Html-Escape($Value) {
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Status-Badge($Status) {
    switch ($Status) {
        "PASS" { return '<span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span>' }
        "FOUND" { return '<span style="color:#008000;font-weight:bold;">FOUND</span>' }
        "CHECK" { return '<span style="color:#b26a00;font-weight:bold;">CHECK</span>' }
        "FAIL" { return '<span style="color:#cc0000;font-weight:bold;font-size:16px;">FAIL</span>' }
        "MISSING" { return '<span style="color:#cc0000;font-weight:bold;">MISSING</span>' }
        default { return "<span>$Status</span>" }
    }
}

function Code-Block($Text, $Kind) {
    return "~~~text`n$Text`n~~~"
}

function File-InfoRow($Path) {
    if (!(Test-Path $Path)) { return "| $Path | $(Status-Badge 'MISSING') | - | - |" }
    $f = Get-Item $Path
    return "| $($f.Name) | $(Status-Badge 'FOUND') | $($f.Length) | $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) |"
}

function Pynq-FileRows($Dir) {
    if (!(Test-Path $Dir)) { return "| $Dir | $(Status-Badge 'MISSING') | - | - |" }
    $files = Get-ChildItem -Path $Dir -File |
        Where-Object { $_.Extension -in ".bit", ".hwh", ".py", ".ipynb" } |
        Sort-Object Extension, Name
    if (!$files) { return "| No board files found | $(Status-Badge 'MISSING') | - | - |" }
    return (($files | ForEach-Object {
        "| $($_.Name) | $(Status-Badge 'FOUND') | $($_.Length) | $($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) |"
    }) -join "`n")
}

function Pynq-UploadText($Dir) {
    if (!(Test-Path $Dir)) { return "pynq folder not found" }
    $files = Get-ChildItem -Path $Dir -File |
        Where-Object { $_.Extension -in ".bit", ".hwh", ".py", ".ipynb" } |
        Sort-Object Extension, Name
    if (!$files) { return "No board files found" }
    return (($files | ForEach-Object { "pynq/$($_.Name)" }) -join "`n")
}

$logText = Read-AllTextSafe $VivadoLog
$timingText = Read-AllTextSafe $TimingRpt
$utilText = Read-AllTextSafe $UtilRpt
$hwhText = Read-AllTextSafe $HwhFile

$bitgenStatus = if ($logText -match "Bitgen Completed Successfully") { "PASS" } elseif (Test-Path $VivadoLog) { "CHECK" } else { "MISSING" }
$copyBitStatus = if ($logText -match "Copied bitstream") { "PASS" } else { "CHECK" }
$copyHwhStatus = if ($logText -match "Copied handoff") { "PASS" } else { "CHECK" }
$ledCtrlStatus = if ($hwhText -match "led_ctrl_0|led_ctrl_axi") { "PASS" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }

$wns = ""
$tns = ""
$whs = ""
$ths = ""
if ($timingText -match "\n\s*([-0-9.]+)\s+([-0-9.]+)\s+\d+\s+\d+\s+([-0-9.]+)\s+([-0-9.]+)") {
    $wns = $Matches[1]
    $tns = $Matches[2]
    $whs = $Matches[3]
    $ths = $Matches[4]
}
$timingStatus = if ($timingText -match "All user specified timing constraints are met") { "PASS" } elseif (Test-Path $TimingRpt) { "CHECK" } else { "MISSING" }

$utilLine = ""
if (Test-Path $UtilRpt) {
    $utilLine = (Select-String -Path $UtilRpt -Pattern "\| Slice LUTs|CLB LUTs|DSPs|Block RAM Tile" | Select-Object -First 8 | ForEach-Object { $_.Line.Trim() }) -join "`n"
}

$timingGoodLine = File-Line $TimingRpt "All user specified timing constraints are met"
$uploadText = Pynq-UploadText $PynqDir
$xprStatus = if (Test-Path $XprFile) { "FOUND" } else { "MISSING" }

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$content = @"
# Vivado Overlay Report

Generated: **$now**

## 1. Build Status

| Item | Status | What It Means |
|---|---|---|
| Bitstream generation | $(Status-Badge $bitgenStatus) | `.bit` was created |
| Copy bit to pynq folder | $(Status-Badge $copyBitStatus) | `pynq/base_add.bit` updated |
| Copy hwh to pynq folder | $(Status-Badge $copyHwhStatus) | `pynq/base_add.hwh` updated |
| RTL LED controller in HWH | $(Status-Badge $ledCtrlStatus) | PS can discover the AXI-Lite LED IP from `.hwh` |
| Routed timing | $(Status-Badge $timingStatus) | Final implemented timing result |

## 2. Output Files For PYNQ

| File | Status | Bytes | Last Write Time |
|---|---|---:|---|
$(Pynq-FileRows $PynqDir)

Upload these files to the PYNQ board after PL hardware changes.

## 3. Timing Summary

Source file:

$(Code-Block $TimingRpt "cmd")

| WNS ns | TNS ns | WHS ns | THS ns | Result |
|---:|---:|---:|---:|---|
| **$wns** | **$tns** | **$whs** | **$ths** | $(Status-Badge $timingStatus) |

Good sign:

$(Code-Block $timingGoodLine "good")

Rule: **WNS > 0** means setup timing passes.

## 4. Resource Report

Source file:

$(Code-Block $UtilRpt "cmd")

Key lines:

$(Code-Block $utilLine "warn")

## 5. Vivado Project

| File | Status |
|---|---|
| build/vivado/base_add_overlay.xpr | $(Status-Badge $xprStatus) |

Open this project only when you want to inspect the block design or timing in the GUI.

## 6. Next Step

If this report shows **PASS**, upload these files to PYNQ:

$(Code-Block $uploadText "cmd")

Then run one of the existing Python scripts on the board, or open an existing
notebook in the board's browser Jupyter.

"@

Set-Content -Path $Out -Value $content -Encoding UTF8
Write-Host ""
Write-Host "========== VIVADO OVERLAY REPORT ==========" -ForegroundColor Cyan
Write-Host "Report file : $Out"
Write-Host "Generated at: $now"
if ($bitgenStatus -eq "PASS") {
    Write-Host "Bitstream   : PASS" -ForegroundColor Green
} elseif ($bitgenStatus -eq "FAIL" -or $bitgenStatus -eq "MISSING") {
    Write-Host "Bitstream   : $bitgenStatus" -ForegroundColor Red
} else {
    Write-Host "Bitstream   : $bitgenStatus" -ForegroundColor Yellow
}
if ($timingStatus -eq "PASS") {
    Write-Host "Timing      : PASS, WNS $wns ns" -ForegroundColor Green
} elseif ($timingStatus -eq "FAIL") {
    Write-Host "Timing      : FAIL, WNS $wns ns" -ForegroundColor Red
} else {
    Write-Host "Timing      : $timingStatus, WNS $wns ns" -ForegroundColor Yellow
}
Write-Host "bit file    : $BitFile"
Write-Host "hwh file    : $HwhFile"
Write-Host "Next step   : upload listed pynq files to PYNQ, then run a script or notebook"
Write-Host "===========================================" -ForegroundColor Cyan
