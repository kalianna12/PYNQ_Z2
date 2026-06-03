# PYNQ-Z2 AD9226 DMA Development Flow

This project currently uses an AXI DMA receive path for AD9226 capture.

## 1. Current Architecture

```text
PS / PYNQ Python
  -> AXI-Lite config registers in adc_capture_0
  -> RTL AD9226 capture or RTL fake stream
  -> 32-bit AXI-Stream packed sample words
  -> Xilinx AXIS Data FIFO
  -> AXI DMA S2MM
  -> PS DDR buffer
  -> numpy / matplotlib / CSV
```

The older HLS `base_add_0` writer path is legacy. It may still exist in the HLS folder and HLS report, but it is not the current DMA validation path.

## 2. Files You Usually Edit

RTL hardware:

```text
rtl/src/ad9226_capture_core.v
rtl/src/adc_sample_fifo.v
rtl/src/adc_capture_system.v
rtl/src/adc_ctrl_axi.v
rtl/tb/tb_ad9226_capture_chain.v
```

Vivado integration:

```text
vivado/build.tcl
constraints/pynq_adc_system.xdc
constraints/pynqz2_leds.xdc
```

PYNQ software:

```text
pynq/ad9226_capture_smoke.py
pynq/ad9226_capture_demo.ipynb
```

Generated or mostly generated:

```text
build/
.Xil/
rtl/sim/
hls/base_add_prj/
pynq/base_add.bit
pynq/base_add.hwh
```

## 3. Build Commands

From the project root:

```powershell
cd G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base
```

Run RTL/HLS checks:

```text
VS Code task: FPGA: 1 Build HLS IP
```

Run Vivado overlay build:

```text
VS Code task: FPGA: 2 Build Vivado Overlay
```

Regenerate reports only:

```text
VS Code task: FPGA: Generate RTL Report Only
VS Code task: FPGA: Generate Vivado Overlay Report Only
```

## 4. How To Confirm DMA Is Integrated

Open `VIVADO_OVERLAY_REPORT.md`. For DMA version, these rows must be PASS:

```text
FCLK_CLK0 in HWH
AXI DMA S2MM in HWH
AXI DMA in BD script
AXIS Data FIFO in HWH
AXIS Data FIFO in BD script
AXIS Data FIFO depth
AXI DMA data widths
adc_capture_0 to AXIS FIFO
AXIS FIFO to DMA S2MM
DMA S2MM to PS HP0
DMA S_AXI_LITE to PS GP0
Routed timing
```

You can also search the HWH:

```powershell
rg "axi_dma_0|axis_data_fifo_0|M_AXIS_SAMPLE|S_AXIS_S2MM|M_AXI_S2MM|S_AXI_HP0" pynq/base_add.hwh
```

Expected path:

```text
adc_capture_0/M_AXIS_SAMPLE
  -> axis_data_fifo_0/S_AXIS
  -> axis_data_fifo_0/M_AXIS
  -> axi_dma_0/S_AXIS_S2MM
  -> axi_dma_0/M_AXI_S2MM
  -> processing_system7_0/S_AXI_HP0
```

Current high-speed settings:

```text
FCLK_CLK0 = 125 MHz
AXIS Data FIFO depth = 16384 words
AXI DMA M_AXI_S2MM = 64 bits
AXI DMA S_AXIS_S2MM = 32 bits
PYNQ buffer dtype = np.uint32
```

## 5. Board Test Order

First test without real ADC:

```bash
python3 ad9226_capture_smoke.py
```

This uses:

```text
capture_mode=2
sample_count=65536
adc_half_period=1
expected ADC_CLK = 62.5 MHz
```

Expected checks:

```text
dma.recvchannel.wait() returns
AXIS_SENT_COUNT == SAMPLE_COUNT
TLAST_COUNT == 1
DROPPED_SAMPLE_COUNT == 0
STATUS.fatal_error == 0
No sentinel values remain in DMA buffer
Fake CH0/CH1 pattern matches
```

Then test in Jupyter:

```text
ad9226_capture_demo.ipynb
```

Only after fake stream passes, use:

```text
capture_mode=1
```

for real AD9226.

Do not use `capture_mode=0` for DMA testing.

## 6. What The Counters Mean

```text
SAMPLE_COUNT
  Number of uint32 packed sample words requested by PS and DMA.

SAMPLE_COUNTER
  Raw ADC sample-edge count before decimation.

SAVED_COUNTER
  capture_core attempted saved count. This is not the final DMA success count.

AXIS_SENT_COUNT
  Number of packed words that actually handshook onto AXI-Stream.

TLAST_COUNT
  Number of successful TLAST handshakes. Must be 1 for a single-shot capture.

DROPPED_SAMPLE_COUNT
  Samples dropped because backpressure prevented acceptance. Must be 0 for full capture.

CORE_DONE
  capture_core finished trying to produce samples.

CAPTURE_DONE_LATCHED / STATUS.done
  Last AXI word with TLAST was sent from RTL side.
```

Main success criterion is DMA + AXIS counters, not `SAVED_COUNTER`.

## 7. When To Rebuild

Rebuild Vivado overlay if you change:

```text
rtl/src/*.v
rtl/tb/*.v if used by reports
constraints/*.xdc
vivado/build.tcl
IP interfaces
AXI/AXIS port definitions
```

You do not need to rebuild bit/hwh if you only change:

```text
pynq/*.py
pynq/*.ipynb
docs/*.md
reports scripts
```

But if you change a report script, rerun the report generator so the visible report matches the current checks.
