# PYNQ-Z2 AD9226 DMA Capture Project

This project is now aligned around the AD9226 RTL capture + AXI DMA S2MM path.
The older HLS `base_add_0` m_axi writer path is legacy/reference material and should not be used to validate the current DMA capture flow.

## Current Status

The active hardware path is:

```text
AD9226 pins or RTL fake stream
  -> adc_capture_0 / M_AXIS_SAMPLE
  -> axis_data_fifo_0
  -> axi_dma_0 S2MM
  -> PS DDR through S_AXI_HP0
  -> PYNQ Python uint32 buffer
```

Current evidence:

- `vivado/build.tcl` creates `axi_dma_0` and `axis_data_fifo_0`.
- `vivado/build.tcl` connects capture AXI-Stream to FIFO, FIFO to DMA S2MM, DMA S2MM to PS HP0.
- `pynq/base_add.hwh` contains `axi_dma_0`, `axis_data_fifo_0`, TKEEP/TLAST, and HP0 memory mapping.
- `axi_dma_0` now uses a 23-bit buffer length register, supporting 65536 packed samples.
- `VIVADO_OVERLAY_REPORT.md` reports the DMA/FIFO/HP0 rows as `PASS`.
- `RTL_REPORT.md` reports the RTL capture chain simulation as `PASS`.

The final board proof is still a PYNQ run of `ad9226_capture_smoke.py` or `ad9226_capture_demo.ipynb`.

## Main Data Format

Each dual-channel sample is one `uint32` packed word:

```text
bits[11:0]   = CH0 / ADC A raw 12-bit code
bits[15:12]  = flags/reserved
bits[27:16]  = CH1 / ADC B raw 12-bit code
bits[31:28]  = flags/reserved
```

PYNQ decode:

```python
raw = np.array(buf, dtype=np.uint32)
ch0 = raw & 0x0FFF
ch1 = (raw >> 16) & 0x0FFF
```

## DMA Capture Modes

Use these modes with DMA:

```text
capture_mode = 2  RTL fake stream -> FIFO -> DMA -> DDR
capture_mode = 1  real AD9226 -> FIFO -> DMA -> DDR
```

Do not use `capture_mode = 0` with DMA. Mode 0 belongs to the old HLS-writer fake path and does not produce AXI-Stream/TLAST data for DMA.

## DMA Success Criteria

A DMA capture run is valid only when:

```text
dma.recvchannel.wait() returns
AXIS_SENT_COUNT == SAMPLE_COUNT
TLAST_COUNT == 1
DROPPED_SAMPLE_COUNT == 0
STATUS.error == 0
captured buffer contains no sentinel values in the requested range
```

`STATUS.error` is fatal-only. `ERROR_FLAGS` may include warning/debug bits such as near-rail or data-changed indicators, so do not treat every nonzero `ERROR_FLAGS` value as a failed DMA capture.

## Directory Structure

```text
PYNQZ2_PSPL_Base/
  constraints/        XDC files for PYNQ-Z2 LEDs and AD9226 pins
  docs/               Design plans, flow notes, and project status
  hls/                Legacy HLS writer/reference flow
  pynq/               Board-side bit/hwh/scripts/notebooks
  rtl/src/            RTL modules
  rtl/tb/             RTL testbench
  scripts/            Build/report helper scripts
  vivado/             Vivado block design build script
```

Important docs:

```text
docs/PROJECT_STATUS.md
docs/FLOW.md
docs/AD9226_AXI_DMA_CAPTURE_PLAN.md
RTL_REPORT.md
VIVADO_OVERLAY_REPORT.md
```

## Build Flow

From this folder:

```powershell
cd G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base
```

Use the VS Code tasks:

```text
FPGA: 1 Build HLS IP
FPGA: 2 Build Vivado Overlay
FPGA: Generate RTL Report Only
FPGA: Generate Vivado Overlay Report Only
```

The current DMA validation mainly depends on the RTL/Vivado overlay report. The HLS report can still exist because the old writer flow is retained, but it is not the main DMA path.

## PYNQ Board Run Order

Copy these active files to the PYNQ board:

```text
pynq/base_add.bit
pynq/base_add.hwh
pynq/ad9226_capture_smoke.py
pynq/ad9226_capture_demo.ipynb
```

Recommended test order:

1. Run `ad9226_capture_smoke.py` with `capture_mode = 2`.
2. Confirm DMA fake stream counters and buffer pattern.
3. Run `ad9226_capture_demo.ipynb` with `capture_mode = 2`.
4. Switch to `capture_mode = 1` for real AD9226 input.
5. Increase sample rate only after counters and waveforms are stable.

## Key Register Offsets

PYNQ `ip.write(offset, value)` and `ip.read(offset)` use IP-local offsets. Do not add the Vivado base address manually.

```text
0x00 CTRL
0x04 STATUS
0x08 SAMPLE_COUNT
0x0C ADC_HALF_PERIOD
0x10 SAMPLE_DELAY
0x14 DECIMATION
0x18 CHANNEL_MASK
0x1C CAPTURE_MODE
0x20 TRIGGER_MODE
0x24 PRE_DELAY
0x38 FIFO_LEVEL / stream pressure debug
0x3C ERROR_FLAGS
0x44 VERSION
0x48 SAVED_COUNTER
0x4C LAST_SAMPLE_WORD
0x50 DEBUG_STATE
0x54 AXIS_SENT_COUNT
0x58 AXIS_STALL_COUNT
0x5C TLAST_COUNT
0x60 FIFO_BACKPRESSURE_SEEN
0x64 DROPPED_SAMPLE_COUNT
0x68 CAPTURE_DONE_LATCHED
0x6C CORE_DONE
```

## Review Notes

- `adc_sample_fifo.v` is currently a one-word AXI-Stream packer/skid stage. Deep buffering is provided by Vivado `axis_data_fifo_0`.
- Current generated `pynq/base_add.hwh` declares `FCLK_CLK0` as 125 MHz, and PYNQ scripts use `PL_CLK_HZ = 125_000_000`.
- Current high-speed DMA settings are AXIS Data FIFO depth 16384 words, AXI DMA `M_AXI_S2MM` 64-bit, and AXIS `S_AXIS_S2MM` still 32-bit packed `uint32`.
- The current ODDR usage is an output register for the divided ADC clock, not the future fast `D1=1, D2=0` ODDR clock generator.
- DMA interrupt is optional in this polling/wait flow.
- A digital timing PASS does not prove external AD9226 wiring works at the highest sample rates.
