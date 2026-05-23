$ErrorActionPreference = "SilentlyContinue"

$Root = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $Root "VIVADO_OVERLAY_REPORT.md"
$VivadoLog = Join-Path $Root "vivado.log"
$TimingRpt = Join-Path $Root "build\vivado\base_add_overlay.runs\impl_1\system_wrapper_timing_summary_routed.rpt"
$UtilRpt = Join-Path $Root "build\vivado\base_add_overlay.runs\impl_1\system_wrapper_utilization_placed.rpt"
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

$logText = Read-AllTextSafe $VivadoLog
$timingText = Read-AllTextSafe $TimingRpt
$utilText = Read-AllTextSafe $UtilRpt

$bitgenStatus = if ($logText -match "Bitgen Completed Successfully") { "PASS" } elseif (Test-Path $VivadoLog) { "CHECK" } else { "MISSING" }
$copyBitStatus = if ($logText -match "Copied bitstream") { "PASS" } else { "CHECK" }
$copyHwhStatus = if ($logText -match "Copied handoff") { "PASS" } else { "CHECK" }

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
$uploadText = "pynq/base_add.bit`npynq/base_add.hwh`npynq/base_add_test.py`npynq/base_add_demo.ipynb"
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
| Routed timing | $(Status-Badge $timingStatus) | Final implemented timing result |

## 2. Output Files For PYNQ

| File | Status | Bytes | Last Write Time |
|---|---|---:|---|
$(File-InfoRow $BitFile)
$(File-InfoRow $HwhFile)

Upload these two files to the PYNQ board after PL hardware changes.

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

Then run **base_add_test.py** on the board, or open the notebook in the board's browser Jupyter.

"@

Set-Content -Path $Out -Value $content -Encoding UTF8
Write-Host "Generated Vivado overlay report: $Out"
