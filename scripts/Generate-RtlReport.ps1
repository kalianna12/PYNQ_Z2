$ErrorActionPreference = "SilentlyContinue"

$Root = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $Root "RTL_REPORT.md"
$RtlSrcDir = Join-Path $Root "rtl\src"
$RtlTbDir = Join-Path $Root "rtl\tb"
$RtlSimLog = Join-Path $Root "rtl\sim\led_ctrl_axi_sim.log"
$RtlInnerSimLog = Join-Path $Root "rtl\sim\led_ctrl_axi_sim.sim\sim_1\behav\xsim\simulate.log"
$AdcRtlSimLog = Join-Path $Root "rtl\sim\ad9226_capture_sim.log"
$AdcInnerSimLog = Join-Path $Root "rtl\sim\ad9226_capture_sim.sim\sim_1\behav\xsim\simulate.log"
$HighSpeedRtlSimLog = Join-Path $Root "rtl\sim_highspeed\ad9226_highspeed_sim.log"
$HighSpeedInnerSimLog = Join-Path $Root "rtl\sim_highspeed\ad9226_highspeed_sim.sim\sim_1\behav\xsim\simulate.log"
$LedXdc = Join-Path $Root "constraints\lemon_pynqz1_board_io.xdc"

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
$adcSimText = Read-AllTextSafe $AdcRtlSimLog
$adcInnerSimText = Read-AllTextSafe $AdcInnerSimLog
$highSpeedSimText = Read-AllTextSafe $HighSpeedRtlSimLog
$highSpeedInnerSimText = Read-AllTextSafe $HighSpeedInnerSimLog
$combinedSimText = "$simText`n$innerSimText`n$adcSimText`n$adcInnerSimText`n$highSpeedSimText`n$highSpeedInnerSimText"

$ledSimStatus = if ("$simText`n$innerSimText" -match "FINAL: PASS") {
    "PASS"
} elseif ("$simText`n$innerSimText" -match "FINAL: FAIL|ERROR:") {
    "FAIL"
} elseif ((Test-Path $RtlSimLog) -or (Test-Path $RtlInnerSimLog)) {
    "CHECK"
} else {
    "MISSING"
}

$adcSimStatus = if ("$adcSimText`n$adcInnerSimText" -match "FINAL: PASS") {
    "PASS"
} elseif ("$adcSimText`n$adcInnerSimText" -match "FINAL: FAIL|ERROR:") {
    "FAIL"
} elseif ((Test-Path $AdcRtlSimLog) -or (Test-Path $AdcInnerSimLog)) {
    "CHECK"
} else {
    "MISSING"
}

$highSpeedSimStatus = if ("$highSpeedSimText`n$highSpeedInnerSimText" -match "FINAL: PASS") {
    "PASS"
} elseif ("$highSpeedSimText`n$highSpeedInnerSimText" -match "FINAL: FAIL|ERROR:") {
    "FAIL"
} elseif ((Test-Path $HighSpeedRtlSimLog) -or (Test-Path $HighSpeedInnerSimLog)) {
    "CHECK"
} else {
    "MISSING"
}

$rtlSimStatus = if (($ledSimStatus -eq "PASS") -and ($adcSimStatus -eq "PASS") -and ($highSpeedSimStatus -eq "PASS")) {
    "PASS"
} elseif (($ledSimStatus -eq "FAIL") -or ($adcSimStatus -eq "FAIL") -or ($highSpeedSimStatus -eq "FAIL")) {
    "FAIL"
} elseif (($ledSimStatus -eq "MISSING") -or ($adcSimStatus -eq "MISSING") -or ($highSpeedSimStatus -eq "MISSING")) {
    "MISSING"
} else {
    "CHECK"
}

$finalLines = @()
if (Test-Path $RtlSimLog) {
    $finalLines += Select-String -Path $RtlSimLog -Pattern "FINAL:" | ForEach-Object { $_.Line.Trim() }
}
if (Test-Path $RtlInnerSimLog) {
    $finalLines += Select-String -Path $RtlInnerSimLog -Pattern "FINAL:" | ForEach-Object { $_.Line.Trim() }
}
if (Test-Path $AdcRtlSimLog) {
    $finalLines += Select-String -Path $AdcRtlSimLog -Pattern "FINAL:" | ForEach-Object { $_.Line.Trim() }
}
if (Test-Path $AdcInnerSimLog) {
    $finalLines += Select-String -Path $AdcInnerSimLog -Pattern "FINAL:" | ForEach-Object { $_.Line.Trim() }
}
if (Test-Path $HighSpeedRtlSimLog) {
    $finalLines += Select-String -Path $HighSpeedRtlSimLog -Pattern "FINAL:" | ForEach-Object { $_.Line.Trim() }
}
if (Test-Path $HighSpeedInnerSimLog) {
    $finalLines += Select-String -Path $HighSpeedInnerSimLog -Pattern "FINAL:" | ForEach-Object { $_.Line.Trim() }
}
$finalText = (($finalLines | Select-Object -Unique) -join "`n").Trim()

$xdcText = ""
if (Test-Path $LedXdc) {
    $xdcText = (Select-String -Path $LedXdc -Pattern "PACKAGE_PIN|IOSTANDARD" | ForEach-Object { $_.Line.Trim() }) -join "`n"
}

$registerText = @"
led_ctrl_axi:
0x00 CTRL        bit0 enable, bits[3:1] mode
0x04 SPEED_DIV   blink/walk/counter divider
0x08 LED_VALUE   manual LED value, bits[3:0]
0x0C STATUS      bits[3:0] current LED, bits[7:4] tick counter

adc_ctrl_axi planned:
0x00 CTRL         bit0 enable, bit1 start pulse, bit2 clear pulse, bit6 soft_reset
0x04 STATUS       done means AXIS TLAST sent; error means fatal only
0x08 SAMPLE_COUNT packed uint32 sample_word count sent to DMA
0x0C ADC_HALF     ADC clock half period
0x10 SAMPLE_DELAY delay in clk_125m cycles
0x14 DECIMATION   save 1 per N ADC samples
0x18 CHANNEL_MASK bit0 A, bit1 B
0x1C CAPTURE_MODE 1 real ADC, 2 capture_core fake stream
0x48 SAVED_COUNTER
0x4C LAST_AXIS_WORD
0x50 DEBUG_STATE
0x54 AXIS_SENT_COUNT
0x58 AXIS_STALL_COUNT
0x5C TLAST_COUNT
0x60 FIFO_BACKPRESSURE
0x64 DROPPED_SAMPLE_COUNT
0x68 CAPTURE_DONE_LATCHED
0x6C CORE_DONE

Warnings such as near_rail/data_changed are debug status, not fatal capture errors.
"@

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$content = @"
# RTL Report

Generated: **$now**

## 1. RTL Simulation Status

| Item | Status | What It Means |
|---|---|---|
| LED AXI-Lite simulation | $(Status-Badge $ledSimStatus) | Existing PS-controlled LED RTL testbench |
| AD9226 capture simulation | $(Status-Badge $adcSimStatus) | New capture_core + FIFO fake/real stream testbench |
| AD9226 high-speed AXIS simulation | $(Status-Badge $highSpeedSimStatus) | adc_half=1 fake and real stream, no dropped samples when tready stays high |
| Overall RTL simulation | $(Status-Badge $rtlSimStatus) | All RTL testbenches before Vivado overlay integration |

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
Vivado `.hwh` or Vivado logs. In PYNQ, `ip.write(offset, value)` uses the
IP-local offset, not base_address + offset.

$(Code-Block $registerText)

## 5. Board Constraints Used By RTL

Source file:

$(Code-Block $LedXdc)

Key pin constraints:

$(Code-Block $xdcText)

## 6. Logs

LED Vivado simulation log:

$(Code-Block $RtlSimLog)

LED inner xsim log:

$(Code-Block $RtlInnerSimLog)

AD9226 capture Vivado simulation log:

$(Code-Block $AdcRtlSimLog)

AD9226 capture inner xsim log:

$(Code-Block $AdcInnerSimLog)

AD9226 high-speed Vivado simulation log:

$(Code-Block $HighSpeedRtlSimLog)

AD9226 high-speed inner xsim log:

$(Code-Block $HighSpeedInnerSimLog)

## 7. Next Step

If this report shows **PASS**, run:

$(Code-Block "FPGA: 2 Build Vivado Overlay")

"@

Set-Content -Path $Out -Value $content -Encoding UTF8

Write-Host ""
Write-Host "========== RTL SUMMARY REPORT ==========" -ForegroundColor Cyan
Write-Host "Report file : $Out"
Write-Host "Generated at: $now"
Write-Host "LED sim     : $ledSimStatus"
Write-Host "AD9226 sim  : $adcSimStatus"
Write-Host "Highspeed   : $highSpeedSimStatus"
if ($rtlSimStatus -eq "PASS") {
    Write-Host "RTL sim     : PASS" -ForegroundColor Green
} elseif ($rtlSimStatus -eq "FAIL" -or $rtlSimStatus -eq "MISSING") {
    Write-Host "RTL sim     : $rtlSimStatus" -ForegroundColor Red
} else {
    Write-Host "RTL sim     : $rtlSimStatus" -ForegroundColor Yellow
}
Write-Host "Next step   : FPGA: 2 Build Vivado Overlay"
Write-Host "========================================" -ForegroundColor Cyan
