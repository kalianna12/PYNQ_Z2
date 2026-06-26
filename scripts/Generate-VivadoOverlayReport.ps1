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
$BuildTcl = Join-Path $Root "vivado\build.tcl"
$RecommendedPynqFiles = @(
    "base_add.bit",
    "base_add.hwh",
    "lemon_pynqz1_capture.py",
    "lemon_pynqz1_board_adc_test.ipynb"
)

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
        "OPTIONAL" { return '<span style="color:#64748b;font-weight:bold;">OPTIONAL</span>' }
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
    $files = @()
    foreach ($name in $RecommendedPynqFiles) {
        $path = Join-Path $Dir $name
        if (Test-Path $path) {
            $files += Get-Item $path
        }
    }
    if (!$files) { return "No board files found" }
    return (($files | ForEach-Object { "pynq/$($_.Name)" }) -join "`n")
}

function Recommended-PynqRows($Dir) {
    if (!(Test-Path $Dir)) { return "| $Dir | $(Status-Badge 'MISSING') | - | - |" }
    return (($RecommendedPynqFiles | ForEach-Object {
        $path = Join-Path $Dir $_
        if (Test-Path $path) {
            $f = Get-Item $path
            "| $($f.Name) | $(Status-Badge 'FOUND') | $($f.Length) | $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) |"
        } else {
            "| $_ | $(Status-Badge 'MISSING') | - | - |"
        }
    }) -join "`n")
}

function Hwh-AddressRows($Text) {
    $rows = @()
    $pattern = '<MEMRANGE[^>]*BASEVALUE="([^"]+)"[^>]*HIGHVALUE="([^"]+)"[^>]*INSTANCE="([^"]+)"[^>]*MEMTYPE="([^"]+)"[^>]*SLAVEBUSINTERFACE="([^"]+)"'
    $matches = [regex]::Matches($Text, $pattern)
    foreach ($m in $matches) {
        $instance = $m.Groups[3].Value
        if ($instance -notin @("led_ctrl_0", "adc_capture_0", "axi_dma_0")) { continue }
        $base = $m.Groups[1].Value
        $high = $m.Groups[2].Value
        $range = "-"
        try {
            $rangeValue = [Convert]::ToInt64($high, 16) - [Convert]::ToInt64($base, 16) + 1
            $range = ("0x{0:X}" -f $rangeValue)
        } catch {}
        $access = switch ($instance) {
            "led_ctrl_0" { "MMIO($base, $range)" }
            "adc_capture_0" { "MMIO($base, $range)" }
            "axi_dma_0" { "overlay.axi_dma_0 / DMA MMIO $base" }
            default { "" }
        }
        $rows += "| $instance | $base | $high | $range | $($m.Groups[5].Value) | $access |"
    }
    if (!$rows) { return "| Address map not found in HWH | $(Status-Badge 'MISSING') | - | - | - | - |" }
    return ($rows -join "`n")
}

function Xdc-PinRows($Paths) {
    $rows = @()
    foreach ($path in $Paths) {
        if (!(Test-Path $path)) { continue }
        $file = Split-Path -Leaf $path
        $matches = Select-String -Path $path -Pattern 'set_property\s+PACKAGE_PIN\s+(\S+)\s+\[get_ports\s+(?:\{([^\}]+)\}|([^\]]+))\]'
        foreach ($m in $matches) {
            $pin = $m.Matches[0].Groups[1].Value
            $port = $m.Matches[0].Groups[2].Value.Trim()
            if (!$port) { $port = $m.Matches[0].Groups[3].Value.Trim() }
            $meaning = switch -Regex ($port) {
                '^leds_4bits_tri_o\[0\]$' { "LD0"; break }
                '^leds_4bits_tri_o\[1\]$' { "LD1"; break }
                '^leds_4bits_tri_o\[2\]$' { "LD2"; break }
                '^leds_4bits_tri_o\[3\]$' { "LD3"; break }
                '^rgb_leds_6bits_tri_o\[0\]$' { "LD5_R"; break }
                '^rgb_leds_6bits_tri_o\[1\]$' { "LD5_G"; break }
                '^rgb_leds_6bits_tri_o\[2\]$' { "LD5_B"; break }
                '^rgb_leds_6bits_tri_o\[3\]$' { "LD4_R"; break }
                '^rgb_leds_6bits_tri_o\[4\]$' { "LD4_G"; break }
                '^rgb_leds_6bits_tri_o\[5\]$' { "LD4_B"; break }
                '^btns_4bits_tri_i\[0\]$' { "BTN0"; break }
                '^btns_4bits_tri_i\[1\]$' { "BTN1"; break }
                '^btns_4bits_tri_i\[2\]$' { "BTN2"; break }
                '^btns_4bits_tri_i\[3\]$' { "BTN3"; break }
                '^adc_a_clk$' { "AD9226 A clock"; break }
                '^adc_b_clk$' { "AD9226 B clock"; break }
                '^adc_a_ora$' { "AD9226 A ORA"; break }
                '^adc_b_orb$' { "AD9226 B ORB"; break }
                '^adc_a_data\[(\d+)\]$' { "AD9226 A D$($Matches[1])"; break }
                '^adc_b_data\[(\d+)\]$' { "AD9226 B D$($Matches[1])"; break }
                default { "" }
            }
            $rows += "| $port | $meaning | $pin | $file |"
        }
    }
    if (!$rows) { return "| Pin constraints not found | $(Status-Badge 'MISSING') | - | - |" }
    return ($rows -join "`n")
}

$logText = Read-AllTextSafe $VivadoLog
$timingText = Read-AllTextSafe $TimingRpt
$utilText = Read-AllTextSafe $UtilRpt
$hwhText = Read-AllTextSafe $HwhFile
$buildText = Read-AllTextSafe $BuildTcl

$vivadoErrorSeen = ($logText -match "ERROR: \[" -or $logText -match "failed due to earlier errors")
$bitgenStatus = if ($vivadoErrorSeen) { "FAIL" } elseif (Test-Path $BitFile) { "PASS" } elseif ($logText -match "Bitgen Completed Successfully") { "PASS" } elseif (Test-Path $VivadoLog) { "CHECK" } else { "MISSING" }
$copyBitStatus = if (Test-Path $BitFile) { "PASS" } elseif ($logText -match "Copied bitstream") { "PASS" } else { "CHECK" }
$copyHwhStatus = if (Test-Path $HwhFile) { "PASS" } elseif ($logText -match "Copied handoff") { "PASS" } else { "CHECK" }
$ledCtrlStatus = if ($hwhText -match "led_ctrl_0|led_ctrl_axi") { "PASS" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$ledPortStatus = if ($hwhText -match "leds_4bits_tri_o") { "PASS" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$rgbPortStatus = if ($hwhText -match "rgb_leds_6bits_tri_o") { "PASS" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$buttonPortStatus = if ($hwhText -match "btns_4bits_tri_i") { "PASS" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$adcCaptureStatus = if ($hwhText -match "adc_capture_0|adc_capture_system") { "PASS" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$dmaStatus = if ($hwhText -match "INSTANCE=`"axi_dma_0`"") { "PASS" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$axisFifoStatus = if ($hwhText -match "INSTANCE=`"axis_data_fifo_0`"") { "PASS" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$axisToFifoStatus = if (($hwhText -match "adc_capture_0_M_AXIS_SAMPLE_TDATA") -and ($hwhText -match "axis_data_fifo_0")) { "PASS" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$fifoToDmaStatus = if (($hwhText -match "axis_data_fifo_0_M_AXIS") -and ($hwhText -match "S_AXIS_S2MM")) { "PASS" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$dmaHpStatus = if (($hwhText -match "axi_dma_0_M_AXI_S2MM") -and ($hwhText -match "S_AXI_HP0")) { "PASS" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$dmaBdStatus = if (($buildText -match "create_bd_cell.*axi_dma_0") -and ($buildText -match "axi_dma_0/S_AXIS_S2MM")) { "PASS" } elseif (Test-Path $BuildTcl) { "CHECK" } else { "MISSING" }
$axisFifoBdStatus = if (($buildText -match "create_bd_cell.*axis_data_fifo_0") -and ($buildText -match "axis_data_fifo_0/S_AXIS") -and ($buildText -match "axis_data_fifo_0/M_AXIS")) { "PASS" } elseif (Test-Path $BuildTcl) { "CHECK" } else { "MISSING" }
$dmaLiteGpStatus = if (($hwhText -match "INSTANCE=`"axi_dma_0`"") -and ($hwhText -match "MASTERBUSINTERFACE=`"M_AXI_GP0`"") -and ($hwhText -match "SLAVEBUSINTERFACE=`"S_AXI_LITE`"")) { "PASS" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$dmaIrqStatus = if (($buildText -match "s2mm_introut.*IRQ_F2P") -or ($hwhText -match "s2mm_introut.*IRQ_F2P")) { "PASS" } else { "OPTIONAL" }
$dmaLengthWidth = ""
if ($hwhText -match 'NAME="c_sg_length_width"\s+VALUE="([^"]+)"') {
    $dmaLengthWidth = $Matches[1]
}
$dmaSg = ""
if ($hwhText -match 'NAME="c_include_sg"\s+VALUE="([^"]+)"') {
    $dmaSg = $Matches[1]
}
$dmaMm2s = ""
if ($hwhText -match 'NAME="c_include_mm2s"\s+VALUE="([^"]+)"') {
    $dmaMm2s = $Matches[1]
}
$dmaS2mm = ""
if ($hwhText -match 'NAME="c_include_s2mm"\s+VALUE="([^"]+)"') {
    $dmaS2mm = $Matches[1]
}
$dmaMDataWidth = ""
if ($hwhText -match 'NAME="c_m_axi_s2mm_data_width"\s+VALUE="([^"]+)"') {
    $dmaMDataWidth = $Matches[1]
}
$dmaSDataWidth = ""
if ($hwhText -match 'NAME="c_s_axis_s2mm_tdata_width"\s+VALUE="([^"]+)"') {
    $dmaSDataWidth = $Matches[1]
}
$axisFifoDepth = ""
if ($hwhText -match 'NAME="FIFO_DEPTH"\s+VALUE="([^"]+)"') {
    $axisFifoDepth = $Matches[1]
} elseif ($hwhText -match 'NAME="C_FIFO_DEPTH"\s+VALUE="([^"]+)"') {
    $axisFifoDepth = $Matches[1]
}
$dmaMaxTransferBytes = 0
if ($dmaLengthWidth -match '^\d+$') {
    $dmaMaxTransferBytes = [int64]([math]::Pow(2, [int]$dmaLengthWidth) - 1)
}
$requiredSampleWords = 262144
$requiredTransferBytes = $requiredSampleWords * 4
$dmaModeStatus = if (($dmaSg -eq "0") -and ($dmaMm2s -eq "0") -and ($dmaS2mm -eq "1")) { "PASS" } elseif ($dmaSg -or $dmaMm2s -or $dmaS2mm) { "FAIL" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$dmaDataWidthStatus = if (($dmaMDataWidth -eq "64") -and ($dmaSDataWidth -eq "32")) { "PASS" } elseif ($dmaMDataWidth -or $dmaSDataWidth) { "FAIL" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$axisFifoDepthStatus = if ($axisFifoDepth -eq "16384") { "PASS" } elseif ($axisFifoDepth) { "FAIL" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$dmaLengthWidthStatus = if ($dmaMaxTransferBytes -ge $requiredTransferBytes) { "PASS" } elseif ($dmaLengthWidth) { "FAIL" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$dmaMaxTransferStatus = if ($dmaMaxTransferBytes -ge $requiredTransferBytes) { "PASS" } elseif ($dmaMaxTransferBytes -gt 0) { "FAIL" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$fclk0Hz = ""
if ($hwhText -match 'PCW_CLK0_FREQ"\s+VALUE="([^"]+)"') {
    $fclk0Hz = $Matches[1]
}
$fclkStatus = if ($fclk0Hz -eq "125000000") { "PASS" } elseif ($fclk0Hz) { "FAIL" } elseif (Test-Path $HwhFile) { "CHECK" } else { "MISSING" }
$fclkNote = if ($fclk0Hz) { "HWH declares FCLK_CLK0 as $fclk0Hz Hz; target is 125000000 Hz and Python PL_CLK_HZ must match." } else { "Could not read FCLK_CLK0 frequency from hwh." }

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
$addressRows = Hwh-AddressRows $hwhText
$pinRows = Xdc-PinRows @(
    (Join-Path $Root "constraints\lemon_pynqz1_board_io.xdc"),
    (Join-Path $Root "constraints\lemon_pynqz1_adc_system.xdc")
)

$ledRegisterRows = @"
| LED_CTRL | 0x00 | write 0x00 for manual board IO mode |
| LED_VALUE | 0x08 | bits[3:0]=LD0..LD3, bits[6:4]=LD5 RGB, bits[9:7]=LD4 RGB |
| LED_STATUS | 0x0C | bits[3:0]=LED value, bits[9:4]=RGB value, bits[13:10]=BTN0..BTN3 |
"@

$adcRegisterRows = @"
| CTRL | 0x00 | bit0 enable, bit1 start pulse, bit2 clear/reset pulse |
| STATUS | 0x04 | busy/done/fatal status |
| SAMPLE_COUNT | 0x08 | number of 32-bit sample words sent to DMA |
| ADC_HALF | 0x0C | ADC clock half-period in 125 MHz FCLK cycles |
| SAMPLE_DELAY | 0x10 | ADC data sample delay in FCLK cycles |
| DECIMATION | 0x14 | save one sample per N ADC cycles |
| CHANNEL_MASK | 0x18 | bit0 channel A, bit1 channel B |
| CAPTURE_MODE | 0x1C | 1 real ADC, 2 fake stream |
| TRIGGER_MODE | 0x20 | current generic tests use 0 |
| PRE_DELAY | 0x24 | current generic tests use 0 |
| BUFFER_SELECT | 0x28 | current generic tests use 0 |
| LATEST_A | 0x2C | latest raw channel A sample |
| LATEST_B | 0x30 | latest raw channel B sample |
| SAMPLE_COUNTER | 0x34 | ADC sample counter |
| FIFO_LEVEL | 0x38 | internal FIFO level |
| ERROR_FLAGS | 0x3C | write all ones to clear warning/error flags |
| VERSION | 0x44 | RTL version/debug value |
| SAVED_COUNTER | 0x48 | saved sample counter |
| LAST_AXIS_WORD | 0x4C | last packed AXIS word |
| DEBUG_STATE | 0x50 | capture FSM debug state |
| AXIS_SENT_COUNT | 0x54 | number of AXIS words sent |
| AXIS_STALL_COUNT | 0x58 | AXIS stall counter |
| TLAST_COUNT | 0x5C | expected 1 per capture |
| FIFO_BACKPRESSURE | 0x60 | FIFO backpressure counter |
| DROPPED_SAMPLE_COUNT | 0x64 | expected 0 |
| CAPTURE_DONE_LATCHED | 0x68 | latched done flag |
| CORE_DONE | 0x6C | capture core done flag |
"@

$dmaRegisterRows = @"
| S2MM_DMASR | 0x34 | DMA S2MM status register used by debug code |
"@

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
| 4 single-color LED output port | $(Status-Badge $ledPortStatus) | leds_4bits_tri_o is exported to board pins |
| 2 RGB LED output port | $(Status-Badge $rgbPortStatus) | rgb_leds_6bits_tri_o is exported to board pins |
| 4 button input port | $(Status-Badge $buttonPortStatus) | btns_4bits_tri_i is exported to board pins |
| AD9226 capture controller in HWH | $(Status-Badge $adcCaptureStatus) | PS can discover adc_capture_0 from hwh |
| AXI DMA S2MM in HWH | $(Status-Badge $dmaStatus) | PS can discover axi_dma_0 and use recvchannel |
| AXI DMA in BD script | $(Status-Badge $dmaBdStatus) | build.tcl creates axi_dma_0 and connects S2MM stream |
| AXIS Data FIFO in HWH | $(Status-Badge $axisFifoStatus) | Xilinx FIFO buffers capture stream before DMA |
| AXIS Data FIFO in BD script | $(Status-Badge $axisFifoBdStatus) | build.tcl creates axis_data_fifo_0 between capture and DMA |
| adc_capture_0 to AXIS FIFO | $(Status-Badge $axisToFifoStatus) | M_AXIS_SAMPLE is wired into axis_data_fifo_0/S_AXIS |
| AXIS FIFO to DMA S2MM | $(Status-Badge $fifoToDmaStatus) | axis_data_fifo_0/M_AXIS is wired into axi_dma_0/S_AXIS_S2MM |
| DMA S2MM to PS HP0 | $(Status-Badge $dmaHpStatus) | axi_dma_0/M_AXI_S2MM reaches PS DDR through S_AXI_HP0 |
| DMA S_AXI_LITE to PS GP0 | $(Status-Badge $dmaLiteGpStatus) | PS can configure DMA registers through M_AXI_GP0 |
| DMA S2MM interrupt | $(Status-Badge $dmaIrqStatus) | Optional; current PYNQ flow can use polling/wait |
| AXI DMA mode | $(Status-Badge $dmaModeStatus) | SG=$dmaSg, MM2S=$dmaMm2s, S2MM=$dmaS2mm |
| AXIS Data FIFO depth | $(Status-Badge $axisFifoDepthStatus) | FIFO_DEPTH=$axisFifoDepth words; target value is 16384 |
| AXI DMA data widths | $(Status-Badge $dmaDataWidthStatus) | M_AXI_S2MM=$dmaMDataWidth bits, S_AXIS_S2MM=$dmaSDataWidth bits; target is 64/32 |
| AXI DMA Buffer Length Register Width | $(Status-Badge $dmaLengthWidthStatus) | c_sg_length_width = $dmaLengthWidth; must cover $requiredSampleWords uint32 samples |
| Max DMA transfer bytes | $(Status-Badge $dmaMaxTransferStatus) | Max BTT = $dmaMaxTransferBytes bytes; $requiredSampleWords samples need $requiredTransferBytes bytes |
| FCLK_CLK0 in HWH | $(Status-Badge $fclkStatus) | $fclkNote |
| Routed timing | $(Status-Badge $timingStatus) | Final implemented timing result |

## 2. PS Address Map For PYNQ

These addresses come from `pynq/base_add.hwh`. Notebook code should use these
fixed MMIO addresses directly instead of guessing through overlay attributes.

| Instance | Base | High | Range | Slave Interface | PYNQ Access |
|---|---:|---:|---:|---|---|
$addressRows

Recommended direct bindings:

$(Code-Block "led_ip = MMIO(0x40000000, 0x1000)`nadc_ip = MMIO(0x40001000, 0x1000)`ndma = overlay.axi_dma_0" "python")

## 3. Register Offsets Used By Notebook

LED/RGB/button controller at ``0x40000000``:

| Register | Offset | Meaning |
|---|---:|---|
$ledRegisterRows

ADC capture controller at ``0x40001000``:

| Register | Offset | Meaning |
|---|---:|---|
$adcRegisterRows

AXI DMA at ``0x40400000``:

| Register | Offset | Meaning |
|---|---:|---|
$dmaRegisterRows

## 4. Exposed PL Pin Map

These rows come from the active Lemon/PYNQ-Z1 XDC files. They are the board pins
the bitstream exposes.

| HDL Top Port | Board Meaning | PACKAGE_PIN | XDC File |
|---|---|---|---|
$pinRows

## 5. Recommended DMA Files For PYNQ

These are the files to copy when validating the current DMA capture path.

| File | Status | Bytes | Last Write Time |
|---|---|---:|---|
$(Recommended-PynqRows $PynqDir)

## 6. Board Files Present

| File | Status | Bytes | Last Write Time |
|---|---|---:|---|
$(Pynq-FileRows $PynqDir)

Legacy board notebooks have been moved to the history folder. Use the Lemon/PYNQ-Z1 notebook for board validation.

## 7. Timing Summary

Source file:

$(Code-Block $TimingRpt "cmd")

| WNS ns | TNS ns | WHS ns | THS ns | Result |
|---:|---:|---:|---:|---|
| **$wns** | **$tns** | **$whs** | **$ths** | $(Status-Badge $timingStatus) |

Good sign:

$(Code-Block $timingGoodLine "good")

Rule: **WNS > 0** means setup timing passes.

## 8. Resource Report

Source file:

$(Code-Block $UtilRpt "cmd")

Key lines:

$(Code-Block $utilLine "warn")

## 9. Vivado Project

| File | Status |
|---|---|
| build/vivado/base_add_overlay.xpr | $(Status-Badge $xprStatus) |

Open this project only when you want to inspect the block design or timing in the GUI.

## 10. Next Step

If this report shows **PASS**, upload these files to PYNQ:

$(Code-Block $uploadText "cmd")

For the Lemon/PYNQ-Z1 board validation path, use:

$(Code-Block "pynq/lemon_pynqz1_board_adc_test.ipynb" "cmd")

Do not use old board notebooks when validating the Lemon/PYNQ-Z1 pinout.
Those belong to the previous board flow and can give misleading LED/button/ADC results.

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
Write-Host "DMA IP      : $dmaStatus"
Write-Host "AXIS FIFO   : $axisFifoStatus"
Write-Host "DMA path    : capture=$axisToFifoStatus fifo=$fifoToDmaStatus hp0=$dmaHpStatus"
Write-Host "DMA BD      : dma=$dmaBdStatus fifo=$axisFifoBdStatus lite=$dmaLiteGpStatus irq=$dmaIrqStatus"
Write-Host "FCLK_CLK0   : $fclk0Hz Hz ($fclkStatus)"
Write-Host "FIFO depth  : $axisFifoDepth words ($axisFifoDepthStatus)"
Write-Host "DMA widths  : M_AXI=$dmaMDataWidth S_AXIS=$dmaSDataWidth ($dmaDataWidthStatus)"
Write-Host "Next step   : upload listed pynq files to PYNQ, then run a script or notebook"
Write-Host "===========================================" -ForegroundColor Cyan
