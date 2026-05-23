$ErrorActionPreference = "SilentlyContinue"

$Root = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $Root "HLS_REPORT.md"
$CsimLog = Join-Path $Root "hls\base_add_prj\solution1\csim\report\base_add_csim.log"
$SynthRpt = Join-Path $Root "hls\base_add_prj\solution1\syn\report\base_add_csynth.rpt"
$IpDir = Join-Path $Root "hls\base_add_prj\solution1\impl\ip"
$HwHeader = Join-Path $Root "hls\base_add_prj\solution1\impl\misc\drivers\base_add_v1_0\src\xbase_add_hw.h"
$HlsLog = Join-Path $Root "vivado_hls.log"

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

function Html-Escape($Value) {
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Status-Badge($Status) {
    switch ($Status) {
        "PASS" { return '<span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span>' }
        "FOUND" { return '<span style="color:#008000;font-weight:bold;">FOUND</span>' }
        "USED" { return '<span style="color:#b26a00;font-weight:bold;">USED</span>' }
        "CHECK" { return '<span style="color:#b26a00;font-weight:bold;">CHECK</span>' }
        "FAIL" { return '<span style="color:#cc0000;font-weight:bold;font-size:16px;">FAIL</span>' }
        "MISSING" { return '<span style="color:#cc0000;font-weight:bold;">MISSING</span>' }
        default { return "<span>$Status</span>" }
    }
}

function Code-Block($Text, $Kind) {
    return "~~~text`n$Text`n~~~"
}

$csimText = Read-AllTextSafe $CsimLog
$rptText = Read-AllTextSafe $SynthRpt
$hlsLogText = Read-AllTextSafe $HlsLog

$csimStatus = if ($csimText -match "CSim done with 0 errors" -and $csimText -match "PASS") { "PASS" } elseif (Test-Path $CsimLog) { "CHECK" } else { "MISSING" }
$exportWorkaround = if ($hlsLogText -match "core_revision workaround|Applying Vivado 2018.2 core_revision workaround") { "USED" } else { "NOT SEEN" }

$target = ""
$estimated = ""
if ($rptText -match "\|ap_clk\s*\|\s*([0-9.]+)\|\s*([0-9.]+)\|") {
    $target = $Matches[1]
    $estimated = $Matches[2]
}
$timingStatus = "UNKNOWN"
if ($target -and $estimated) {
    if ([double]$estimated -lt [double]$target) { $timingStatus = "PASS" } else { $timingStatus = "FAIL" }
}

$latencyMin = ""
$latencyMax = ""
$intervalMin = ""
$intervalMax = ""
if ($rptText -match "\|\s*([0-9]+)\|\s*([0-9]+)\|\s*([0-9]+)\|\s*([0-9]+)\|\s*none\s*\|") {
    $latencyMin = $Matches[1]
    $latencyMax = $Matches[2]
    $intervalMin = $Matches[3]
    $intervalMax = $Matches[4]
}

$resourceTotal = ""
if ($rptText -match "\|Total\s*\|\s*([0-9]+)\|\s*([0-9]+)\|\s*([0-9]+)\|\s*([0-9]+)\|") {
    $resourceTotal = "| BRAM_18K | DSP48E | FF | LUT |`n|---:|---:|---:|---:|`n| $($Matches[1]) | $($Matches[2]) | $($Matches[3]) | $($Matches[4]) |"
} else {
    $resourceTotal = "Resource table not found."
}

$ipComponent = Join-Path $IpDir "component.xml"
$ipZip = Join-Path $IpDir "xilinx_com_hls_base_add_1_0.zip"
$ipStatus = if ((Test-Path $ipComponent) -and (Test-Path $ipZip)) { "PASS" } elseif (Test-Path $IpDir) { "CHECK" } else { "MISSING" }
$componentStatus = if (Test-Path $ipComponent) { "FOUND" } else { "MISSING" }
$zipStatus = if (Test-Path $ipZip) { "FOUND" } else { "MISSING" }

$registerLines = @()
if (Test-Path $HwHeader) {
    $registerLines = Select-String -Path $HwHeader -Pattern "ADDR_.*0x" | ForEach-Object { $_.Line.Trim() }
}

$passLine = File-Line $CsimLog "PASS"
$csimDoneLine = File-Line $CsimLog "CSim done"
$csimKeyText = "$passLine`n$csimDoneLine".Trim()
$regText = ($registerLines -join "`n").Trim()

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$content = @"
# HLS Report

Generated: **$now**

## 1. Build Status

| Item | Status | What It Means |
|---|---|---|
| C simulation | $(Status-Badge $csimStatus) | Testbench result |
| Timing estimate | $(Status-Badge $timingStatus) | Estimated clock should be smaller than target |
| IP export | $(Status-Badge $ipStatus) | Vivado can import this HLS IP |
| Vivado 2018.2 date workaround | $(Status-Badge $exportWorkaround) | Normal for old Vivado on modern dates |

## 2. C Simulation

Source file:

$(Code-Block $CsimLog "cmd")

Key result:

$(Code-Block $csimKeyText "good")

## 3. Timing

| Clock | Target ns | Estimated ns | Result |
|---|---:|---:|---|
| ap_clk | **$target** | **$estimated** | $(Status-Badge $timingStatus) |

Rule: **Estimated < Target** means the HLS estimate is acceptable.

## 4. Latency

| Latency min | Latency max | Interval min | Interval max |
|---:|---:|---:|---:|
| **$latencyMin** | **$latencyMax** | **$intervalMin** | **$intervalMax** |

## 5. Resource Estimate

$resourceTotal

## 6. Generated IP

| File | Status |
|---|---|
| hls/base_add_prj/solution1/impl/ip/component.xml | $(Status-Badge $componentStatus) |
| hls/base_add_prj/solution1/impl/ip/xilinx_com_hls_base_add_1_0.zip | $(Status-Badge $zipStatus) |

## 7. AXI-Lite Register Addresses

Read these addresses in Python with `ip.write()` and `ip.read()`.

$(Code-Block $regText "reg")

## 8. Next Step

If this report shows **PASS**, run:

$(Code-Block "FPGA: 2 Build Vivado Overlay" "cmd")

"@

Set-Content -Path $Out -Value $content -Encoding UTF8
Write-Host "Generated HLS report: $Out"
