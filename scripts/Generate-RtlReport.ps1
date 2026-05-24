$ErrorActionPreference = "SilentlyContinue"

$Root = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $Root "RTL_REPORT.md"
$RtlSrcDir = Join-Path $Root "rtl\src"
$RtlTbDir = Join-Path $Root "rtl\tb"
$RtlSimLog = Join-Path $Root "rtl\sim\led_ctrl_axi_sim.log"
$RtlInnerSimLog = Join-Path $Root "rtl\sim\led_ctrl_axi_sim.sim\sim_1\behav\xsim\simulate.log"
$LedXdc = Join-Path $Root "constraints\pynqz2_leds.xdc"

function Read-AllTextSafe($Path) {
    if (Test-Path $Path) { return [System.IO.File]::ReadAllText($Path) }
    return ""
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

function Code-Block($Text) {
    return "~~~text`n$Text`n~~~"
}

function File-Table($Dir, $Pattern) {
    if (!(Test-Path $Dir)) { return "| $Dir | $(Status-Badge 'MISSING') | - |" }
    $rows = Get-ChildItem -Path $Dir -Filter $Pattern -File | Sort-Object Name | ForEach-Object {
        "| $($_.Name) | $(Status-Badge 'FOUND') | $($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) |"
    }
    if (!$rows) { return "| $Dir | $(Status-Badge 'MISSING') | - |" }
    return ($rows -join "`n")
}

$simText = Read-AllTextSafe $RtlSimLog
$innerSimText = Read-AllTextSafe $RtlInnerSimLog
$combinedSimText = "$simText`n$innerSimText"

$rtlSimStatus = if ($combinedSimText -match "FINAL: PASS") {
    "PASS"
} elseif ($combinedSimText -match "FINAL: FAIL|ERROR:") {
    "FAIL"
} elseif ((Test-Path $RtlSimLog) -or (Test-Path $RtlInnerSimLog)) {
    "CHECK"
} else {
    "MISSING"
}

$finalLines = @()
if (Test-Path $RtlSimLog) {
    $finalLines += Select-String -Path $RtlSimLog -Pattern "FINAL:" | ForEach-Object { $_.Line.Trim() }
}
if (Test-Path $RtlInnerSimLog) {
    $finalLines += Select-String -Path $RtlInnerSimLog -Pattern "FINAL:" | ForEach-Object { $_.Line.Trim() }
}
$finalText = (($finalLines | Select-Object -Unique) -join "`n").Trim()

$xdcText = ""
if (Test-Path $LedXdc) {
    $xdcText = (Select-String -Path $LedXdc -Pattern "PACKAGE_PIN|IOSTANDARD" | ForEach-Object { $_.Line.Trim() }) -join "`n"
}

$registerText = @"
0x00 CTRL        bit0 enable, bits[3:1] mode
0x04 SPEED_DIV   blink/walk/counter divider
0x08 LED_VALUE   manual LED value, bits[3:0]
0x0C STATUS      bits[3:0] current LED, bits[7:4] tick counter
"@

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$content = @"
# RTL Report

Generated: **$now**

## 1. RTL Simulation Status

| Item | Status | What It Means |
|---|---|---|
| RTL behavioral simulation | $(Status-Badge $rtlSimStatus) | Verilog testbench result before Vivado overlay integration |

Key result:

$(Code-Block $finalText)

## 2. RTL Source Files

| File | Status | Last Write Time |
|---|---|---|
$(File-Table $RtlSrcDir "*.v")

## 3. RTL Testbench Files

| File | Status | Last Write Time |
|---|---|---|
$(File-Table $RtlTbDir "*.v")

## 4. Simulated Register Map

These are RTL module offsets. The base address must still come from generated
Vivado `.hwh` or Vivado logs.

$(Code-Block $registerText)

## 5. Board Constraints Used By RTL

Source file:

$(Code-Block $LedXdc)

Key pin constraints:

$(Code-Block $xdcText)

## 6. Logs

Main Vivado simulation log:

$(Code-Block $RtlSimLog)

Inner xsim log:

$(Code-Block $RtlInnerSimLog)

## 7. Next Step

If this report shows **PASS**, run:

$(Code-Block "FPGA: 2 Build Vivado Overlay")

"@

Set-Content -Path $Out -Value $content -Encoding UTF8

Write-Host ""
Write-Host "========== RTL SUMMARY REPORT ==========" -ForegroundColor Cyan
Write-Host "Report file : $Out"
Write-Host "Generated at: $now"
if ($rtlSimStatus -eq "PASS") {
    Write-Host "RTL sim     : PASS" -ForegroundColor Green
} elseif ($rtlSimStatus -eq "FAIL" -or $rtlSimStatus -eq "MISSING") {
    Write-Host "RTL sim     : $rtlSimStatus" -ForegroundColor Red
} else {
    Write-Host "RTL sim     : $rtlSimStatus" -ForegroundColor Yellow
}
Write-Host "Next step   : FPGA: 2 Build Vivado Overlay"
Write-Host "========================================" -ForegroundColor Cyan
