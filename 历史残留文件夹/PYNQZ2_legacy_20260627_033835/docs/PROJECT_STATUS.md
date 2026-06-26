# Project Status

Last reviewed: 2026-06-03

## Current Architecture

The current active capture path is the AD9226 RTL + AXI DMA path:

```text
AD9226 pins or RTL fake stream
  -> adc_capture_0 / M_AXIS_SAMPLE
  -> axis_data_fifo_0
  -> axi_dma_0 S2MM
  -> PS DDR through S_AXI_HP0
  -> PYNQ Python uint32 buffer
```

The previous HLS `base_add_0` m_axi writer path is kept only as legacy/reference material. Do not use `overlay.base_add_0` to validate the DMA capture path.

## DMA Integration Check

DMA is integrated in the current Vivado overlay artifacts.

Evidence:

- `vivado/build.tcl` creates `axi_dma_0` and `axis_data_fifo_0`.
- `vivado/build.tcl` connects `adc_capture_0/M_AXIS_SAMPLE` to `axis_data_fifo_0/S_AXIS`.
- `vivado/build.tcl` connects `axis_data_fifo_0/M_AXIS` to `axi_dma_0/S_AXIS_S2MM`.
- `vivado/build.tcl` connects `axi_dma_0/M_AXI_S2MM` to `processing_system7_0/S_AXI_HP0`.
- `vivado/build.tcl` connects `axi_dma_0/S_AXI_LITE` to PS `M_AXI_GP0`.
- `axi_dma_0` uses `c_sg_length_width = 23`, so the maximum BTT is 8,388,607 bytes.
- `processing_system7_0/FCLK_CLK0` is configured to 125 MHz and drives capture, AXIS FIFO, DMA, and HP0 clocks.
- `axis_data_fifo_0` is configured to 16384 words.
- `axi_dma_0` keeps `S_AXIS_S2MM` at 32 bits and uses 64-bit `M_AXI_S2MM`.
- `pynq/base_add.hwh` contains `axi_dma_0`, `axis_data_fifo_0`, `TKEEP`, `TLAST`, and the HP0 memory range.
- `VIVADO_OVERLAY_REPORT.md` reports DMA/FIFO/HP0 rows as `PASS`.
- Current routed timing passes with WNS about 0.500 ns.

## Active PYNQ Files

Use these files for the current DMA flow:

```text
pynq/base_add.bit
pynq/base_add.hwh
pynq/ad9226_capture_smoke.py
pynq/ad9226_capture_demo.ipynb
```

Legacy notebooks in `pynq/` are not the first choice for DMA validation if they refer to `overlay.base_add_0`.

## Completion Rules

For DMA capture, a run is successful only when these conditions hold:

- `dma.recvchannel.wait()` returns without timeout.
- `AXIS_SENT_COUNT == SAMPLE_COUNT`.
- `TLAST_COUNT == 1`.
- `DROPPED_SAMPLE_COUNT == 0`.
- `STATUS.error` is 0. This bit is fatal-only.
- The DMA buffer no longer contains sentinel values in the captured range.

`ERROR_FLAGS` may include warning/debug bits such as near-rail or data-changed indicators. Do not treat every nonzero `ERROR_FLAGS` value as capture failure.

## Capture Modes

Use these modes in the DMA flow:

- `capture_mode = 2`: RTL fake stream through FIFO/DMA. Test this first.
- `capture_mode = 1`: real AD9226 capture through FIFO/DMA.
- `capture_mode = 0`: legacy HLS writer fake mode. Do not use it with DMA transfer/wait, because it does not produce AXI-Stream data.

## Remaining Review Points

- Board-level DMA proof still needs to be run on PYNQ after copying the active files.
- Clock note: `pynq/base_add.hwh` now declares `FCLK_CLK0` as 125 MHz, and the current PYNQ scripts use `PL_CLK_HZ = 125_000_000`.
- `adc_sample_fifo.v` is now a one-word AXI-Stream packer/skid stage. The deep buffer is the Vivado `axis_data_fifo_0` IP.
- The current ADC clock ODDR usage is an output register for the divided clock. It is not the future fast `D1=1, D2=0` ODDR clock generator.
- DMA interrupt is optional in this flow. Current validation can use PYNQ `wait()`/polling.
- External AD9226 wiring and analog front-end quality still determine whether high-speed real capture works, even when digital WNS passes.
