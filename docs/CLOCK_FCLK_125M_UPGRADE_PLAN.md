# Clock And 125 MHz Upgrade Plan

Last reviewed: 2026-06-03

This document records the current clock path, current parameters, and the staged upgrade plan for higher AD9226/DMA capture performance. The first high-speed upgrade stage has now been implemented:

```text
FCLK_CLK0 = 125 MHz
AXIS Data FIFO depth = 16384 words
AXI DMA M_AXI_S2MM = 64 bits
AXIS S_AXIS_S2MM = 32 bits
Python PL_CLK_HZ = 125_000_000
```

## 1. Current Clock Source

The current project does **not** directly use the PYNQ-Z2 board 125 MHz oscillator through a PL top-level `sys_clk` / `clk_125m` input pin.

There is no current evidence of this path:

```text
Board 125 MHz oscillator pin, for example H16
  -> top-level sys_clk / clk_125m input
  -> XDC create_clock on sys_clk
  -> capture logic
```

Instead, the current design uses the PS-generated fabric clock:

```text
processing_system7_0/FCLK_CLK0
  -> adc_capture_0/S_AXI_ACLK
  -> adc_capture_system.v
  -> ad9226_capture_core.v clk_125m port
```

This is confirmed by:

```text
rtl/src/adc_capture_system.v:
  .clk_125m(S_AXI_ACLK)

vivado/build.tcl:
  processing_system7_0/FCLK_CLK0 is connected to:
    adc_capture_0/S_AXI_ACLK
    axi_dma_0/s_axi_lite_aclk
    axi_dma_0/m_axi_s2mm_aclk
    axis_data_fifo_0/s_axis_aclk
    axis_data_fifo_0/m_axis_aclk
    processing_system7_0/S_AXI_HP0_ACLK

pynq/base_add.hwh:
  FCLK_CLK0 -> adc_capture_0/S_AXI_ACLK
  FCLK_CLK0 -> axi_dma_0/m_axi_s2mm_aclk
  FCLK_CLK0 -> axis_data_fifo_0/s_axis_aclk
  FCLK_CLK0 -> processing_system7_0/S_AXI_HP0_ACLK
```

Conclusion: the AI suggestion is correct on the main clock-source point. The project is currently driven by PS `FCLK_CLK0`, not an external PL oscillator input.

## 2. Current Clock Parameters

Current generated HWH reports:

```text
PCW_FPGA0_PERIPHERAL_FREQMHZ = 125.000000
PCW_CLK0_FREQ               = 125000000
FCLK_CLK0 CLKFREQUENCY      = 125000000
S_AXI_HP0_ACLK              = FCLK_CLK0
M_AXI_GP0_ACLK              = FCLK_CLK0
axi_dma_0/m_axi_s2mm_aclk   = FCLK_CLK0
axis_data_fifo_0/s_axis_aclk = FCLK_CLK0
adc_capture_0/S_AXI_ACLK    = FCLK_CLK0
```

Current PYNQ scripts use:

```python
PL_CLK_HZ = 125_000_000
```

The generated HWH, report script, and Python constants are now aligned at 125 MHz.

Recommended confirmation before changing the architecture:

```text
1. Check HWH after every build for PCW_CLK0_FREQ.
2. Measure adc_a_clk / adc_b_clk on a scope for a known ADC_HALF value.
3. Compare measured Fs with:
   Fs_adc = FCLK_CLK0 / (2 * ADC_HALF_PERIOD)
```

## 3. Current ADC Clock Generation

Current RTL uses `adc_half_period_cfg` to generate a divided ADC clock:

```text
adc_clk_div_r toggles every ADC_HALF_PERIOD FCLK cycles

ADC_CLK = FCLK_CLK0 / (2 * ADC_HALF_PERIOD)
```

For current 125 MHz FCLK:

```text
ADC_HALF = 1  -> 62.5 MSPS
ADC_HALF = 2  -> 31.25 MSPS
ADC_HALF = 3  -> 20.833 MSPS
ADC_HALF = 6  -> 10.417 MSPS
ADC_HALF = 12 -> 5.208 MSPS
```

## 4. Current ODDR Status

The current RTL instantiates ODDR, but it is not using the classic fixed clock-output pattern:

```verilog
D1 = adc_clk_div_r
D2 = adc_clk_div_r
```

Meaning:

```text
FCLK_CLK0
  -> fabric divider adc_clk_div_r
  -> ODDR output register
  -> adc_a_clk / adc_b_clk
```

This preserves dynamic PS control through `ADC_HALF_PERIOD`.

Important correction to the pasted AI text:

```text
ODDR with C=125 MHz, D1=1, D2=0 normally outputs a 125 MHz 50% duty clock.
It does not output 62.5 MHz.
```

To get about 62.5 MHz from a 125 MHz clock, the current divider-style method is conceptually correct:

```text
adc_half_period = 1
adc_clk_div_r toggles once per FCLK cycle
ADC_CLK period = 2 FCLK cycles
ADC_CLK = 62.5 MHz when FCLK = 125 MHz
```

So the implemented high-speed AD9226 mode keeps the divider and uses `adc_half_period=1` for 62.5 MSPS. A true `D1=1, D2=0` ODDR branch is useful only if a future design needs a 125 MHz output clock for a different ADC.

## 5. Current DMA/AXIS Parameters

Current DMA path:

```text
adc_capture_0/M_AXIS_SAMPLE
  -> axis_data_fifo_0/S_AXIS
  -> axis_data_fifo_0/M_AXIS
  -> axi_dma_0/S_AXIS_S2MM
  -> axi_dma_0/M_AXI_S2MM
  -> processing_system7_0/S_AXI_HP0
```

Current relevant DMA parameters:

```text
Scatter Gather        = disabled
MM2S                  = disabled
S2MM                  = enabled
S_AXIS_S2MM width     = 32 bits
M_AXI_S2MM width      = 64 bits
Buffer length width   = 23 bits
Max BTT               = 8,388,607 bytes
AXIS Data FIFO depth  = 16384 words
HP0 data width        = 64 bits at the PS interface
HP0 clock             = FCLK_CLK0
```

The BTT-size problem has been fixed. Large transfers such as:

```text
65536 packed sample words * 4 bytes = 262144 bytes
```

are now within the DMA transfer-length limit.

The remaining bottleneck, if any, is board-level real ADC timing or stream/DDR throughput under full-speed load, not DMA BTT width.

## 6. Performance Target Reality Check

### Dual-channel AD9226 target

AD9226 is about a 65 MSPS-class ADC. A realistic high-speed target is:

```text
FCLK_CLK0 = 125 MHz
ADC_HALF_PERIOD = 1
ADC_CLK ~= 62.5 MHz
one packed uint32 per dual-channel sample pair
bandwidth ~= 62.5M * 4 = 250 MB/s
```

This is aggressive but plausible with AXI DMA + HP port if timing, FIFO, DDR arbitration, and PYNQ buffer behavior are good.

### Single-channel 125 MSPS target

Single-channel 125 MSPS is not realistic with AD9226 if the actual ADC hardware is AD9226-class.

If a future ADC really supports 125 MSPS, then a different capture mode is needed:

```text
125 MHz ADC clock
single-channel sample every 8 ns
more careful input timing
IOB registers / IDDR / phase tuning likely needed
better packing to reduce DDR bandwidth
```

If one 12-bit sample is stored as one uint32:

```text
125M * 4 bytes = 500 MB/s
```

That is too high for this simple first DMA path. A more realistic layout packs samples:

```text
two 12-bit/16-bit single-channel samples per uint32
or four samples per uint64
```

## 7. Recommended Upgrade Plan

### Phase 1: Make PS FCLK_CLK0 Explicitly 125 MHz

Goal:

```text
processing_system7_0/FCLK_CLK0 = 125 MHz
```

Do not introduce the external H16 board oscillator yet. Keep the current PS FCLK architecture.

Planned changes:

```text
vivado/build.tcl:
  Set processing_system7_0 FPGA0/FCLK0 peripheral frequency to 125 MHz.
  Keep S_AXI_HP0 enabled.
  Keep FCLK_CLK0 connected to:
    adc_capture_0/S_AXI_ACLK
    axis_data_fifo_0/s_axis_aclk
    axis_data_fifo_0/m_axis_aclk
    axi_dma_0/s_axi_lite_aclk
    axi_dma_0/m_axi_s2mm_aclk
    processing_system7_0/S_AXI_HP0_ACLK

pynq scripts:
  PL_CLK_HZ = 125_000_000

report:
  Check PCW_CLK0_FREQ == 125000000
  Check all DMA/AXIS/HP0 clock ports are still connected to FCLK_CLK0
```

Validation:

```text
1. Rebuild overlay.
2. Confirm timing PASS.
3. Confirm HWH reports FCLK_CLK0 = 125000000.
4. Run capture_mode=2 fake stream:
   sample_count = 1024
   sample_count = 32768
   sample_count = 65536
5. Then test real ADC mode at:
   ADC_HALF = 12
   ADC_HALF = 6
   ADC_HALF = 3
   ADC_HALF = 2
   ADC_HALF = 1
```

### Phase 2: Keep Dynamic Divider For AD9226 62.5 MSPS

For AD9226 high-speed dual-channel mode, keep:

```text
ADC_CLK = 125 MHz / (2 * ADC_HALF_PERIOD)
```

Then:

```text
ADC_HALF = 1 -> 62.5 MSPS
```

Do not replace this with `ODDR(D1=1,D2=0)` unless the target is a true 125 MHz ADC clock.

Recommended RTL naming cleanup only after Phase 1:

```text
clk_125m input name is currently correct only if FCLK really is 125 MHz.
If FCLK remains configurable, consider renaming internally to pl_clk or fclk.
```

### Phase 3: Improve DMA Width If 62.5 MSPS Is Not Stable

If `ADC_HALF=1`, `decimation=1`, dual-channel capture drops samples:

```text
AXIS_STALL_COUNT > 0
DROPPED_SAMPLE_COUNT > 0
FIFO_BACKPRESSURE_SEEN = 1
DMA timeout
```

then improve throughput:

```text
M_AXI_S2MM data width: 32 -> 64
Consider AXIS stream width: 32 -> 64
Pack two sample-pairs per 64-bit beat
Keep HP0 at 64-bit
Increase AXIS FIFO depth if needed
```

This reduces pressure on the DMA write channel.

### Phase 4: Optional True 125 MHz Single-Channel Mode

Only if the ADC hardware supports 125 MSPS:

```text
Add a separate capture_mode for single-channel high-speed.
Use ODDR D1=1, D2=0 only if outputting a true FCLK-frequency ADC clock.
Use IOB input registers or IDDR as needed.
Pack samples efficiently before DMA.
Add ILA/debug bitstream for timing bring-up.
```

This is a separate architecture step, not a small parameter tweak.

## 8. Proposed Report Checks

Add these checks to the Vivado overlay report before implementing the upgrade:

```text
FCLK_CLK0 frequency == 125000000
adc_capture_0/S_AXI_ACLK connected to FCLK_CLK0
axis_data_fifo_0/s_axis_aclk connected to FCLK_CLK0
axis_data_fifo_0/m_axis_aclk connected to FCLK_CLK0
axi_dma_0/m_axi_s2mm_aclk connected to FCLK_CLK0
processing_system7_0/S_AXI_HP0_ACLK connected to FCLK_CLK0
DMA BTT width >= 23
DMA S2MM enabled, MM2S disabled, SG disabled
Timing WNS > 0
```

## 9. Recommended Decision

Use this route first:

```text
PS FCLK_CLK0 = 125 MHz
single-clock-domain capture/DMA remains unchanged
ADC_HALF_PERIOD controls AD9226 sampling rate
ADC_HALF_PERIOD = 1 gives about 62.5 MSPS
```

Do not use the external H16 oscillator path yet. It adds top-level ports, XDC work, and extra risk without being necessary for the current upgrade.

Do not treat `ODDR(D1=1,D2=0)` as the answer for 62.5 MHz from 125 MHz. That pattern is for outputting a clock at the ODDR input-clock frequency.
