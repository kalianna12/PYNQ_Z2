# ADC + DDS PYNQ-Z1 Snapshot

This folder is a restorable snapshot of the currently working PYNQ-Z1 ADC+DDS
overlay. Keep it as the known-good version before replacing AD9226 ADC logic
with the next AD9767 module work.

## What This Version Contains

- Board: LEMON/PYNQ-Z1 compatible Zynq-7020 board.
- PL board IO exposed to PS:
  - LD0..LD3
  - LD4/LD5 RGB LEDs
  - BTN0..BTN3
- ADC: dual-channel AD9226 capture path.
  - Physical ADC clock fixed at 62.5 MSPS.
  - Saved sample rate is controlled by decimation in PS code.
  - Stream path is ADC capture -> AXIS FIFO -> AXI DMA S2MM -> PS DDR.
- DDS: AD9102 controller.
  - External oscillator is 180 MHz.
  - Supports DDS sine output and SRAM arbitrary waveform mode.
  - Frequency tuning uses `FTW = round(freq_hz * 2^24 / 180 MHz)`.

## Files To Copy To PYNQ

Copy the contents of `deploy/pynq/` to one directory on the PYNQ board, for
example `/home/xilinx/adc_dds_pynqz1/`.

Important files:

- `base_add.bit`: bitstream to load.
- `base_add.hwh`: hardware handoff for PYNQ overlay discovery.
- `lemon_pynqz1_board_adc_test.ipynb`: board IO, fake DMA, real ADC test.
- `lemon_pynqz1_adc_dds_test.ipynb`: AD9102 DDS plus ADC capture test.
- `lemon_pynqz1_capture.py`: board IO and AD9226/DMA helper.
- `lemon_pynqz1_ad9102.py`: AD9102 helper.

## Fixed PS Addresses

Use direct MMIO addresses in notebooks. Do not rely on hierarchy `.write()`
methods for custom RTL IP.

| IP | Address | Range | Python binding |
|---|---:|---:|---|
| `led_ctrl_0` | `0x40000000` | `0x1000` | `MMIO(0x40000000, 0x1000)` |
| `adc_capture_0` | `0x40001000` | `0x1000` | `MMIO(0x40001000, 0x1000)` |
| `ad9102_ctrl_0` | `0x40002000` | `0x1000` | `MMIO(0x40002000, 0x1000)` |
| `axi_dma_0` | `0x40400000` | `0x10000` | `overlay.axi_dma_0` |

## Quick PYNQ Use

In Jupyter, open `lemon_pynqz1_adc_dds_test.ipynb` from the copied folder and run
cells in order:

1. Load `base_add.bit` and bind MMIO/DMA objects.
2. Reset/configure AD9102 and output a sine wave.
3. Optionally verify higher-frequency sine, such as 60 MHz.
4. Optionally load SRAM arbitrary waveform.
5. Capture DDS analog output through ADC and display the waveform.

For board-only and ADC-only checks, use `lemon_pynqz1_board_adc_test.ipynb`.

## Known-Good Board IO Mapping

Board LED and button tests have been verified with the notebook code in this
snapshot.

| Function | FPGA pin |
|---|---|
| LD0 | R14 |
| LD1 | P14 |
| LD2 | N16 |
| LD3 | M14 |
| BTN0 | D19 |
| BTN1 | D20 |
| BTN2 | L20 |
| BTN3 | L19 |
| LD5 R/G/B | M15 / L14 / G14 |
| LD4 R/G/B | N15 / G17 / L15 |

## AD9226 ADC Mapping

This is the part expected to be removed or replaced for the AD9767 phase.

| Signal | FPGA pin |
|---|---|
| ADC A clock | T9 |
| ADC B clock | V11 |
| ADC A data[0..11] | U10 V6 W6 Y9 Y8 Y7 Y6 T5 U5 U7 V7 V8 |
| ADC A ORA | W8 |
| ADC B data[0..11] | V10 Y12 Y13 W11 Y11 V5 J15 H15 F16 F19 F20 B19 |
| ADC B ORB | A20 |

## AD9102 DDS Mapping

Keep this part when replacing the ADC with AD9767 unless the wiring changes.

| Signal | FPGA pin |
|---|---|
| CS_N | U12 |
| SDO | V13 |
| SDIO | T15 |
| SCLK | U17 |
| CLK_CMOS_IN | U13 |
| TRIGGER_N | T14 |
| RESET_N | T16 |

## Current Vivado Result

The included `VIVADO_OVERLAY_REPORT.md` records the current build result:

- Timing PASS.
- WNS: `+0.631 ns`.
- WHS: `+0.014 ns`.
- All user-specified timing constraints are met.

## Source Snapshot

The source files needed to rebuild or inspect this exact version are copied into:

- `rtl/src/`
- `rtl/tb/`
- `constraints/`
- `vivado/build.tcl`
- `scripts/`
- `docs/`

Generated Vivado project directories such as `build/`, `.Xil/`, simulation
cache directories, and Python `__pycache__` files are intentionally not copied.

## Next Work Boundary

For the next AD9767 version:

- Keep board IO, AD9102 DDS, PS address style, and notebook direct-MMIO pattern.
- Remove or isolate AD9226-specific RTL/XDC/notebook cells.
- Add AD9767 PL interface and expose its control registers to PS.
- Regenerate `base_add.bit`, `base_add.hwh`, and the Vivado overlay report.
