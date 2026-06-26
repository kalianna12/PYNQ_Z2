# Lemon PYNQ-Z1 AD9226 Overlay

This workspace is the cleaned Lemon/PYNQ-Z1 development tree for generic AD9226
capture and board IO validation.

The current target is:

```text
Board      : Lemon ZYNQ / PYNQ-Z1-compatible board
FPGA       : XC7Z020 CLG400
Vivado     : 2022.1
PYNQ image : 3.0.1
Overlay    : PS-controlled LED/RGB/button test + AD9226 capture + AXI DMA
```

## Active Files

```text
vivado/build.tcl
  Creates the Vivado block design and copies base_add.bit/base_add.hwh to pynq/.

constraints/lemon_pynqz1_board_io.xdc
  Lemon/PYNQ-Z1 LED, RGB LED, and button pins.

constraints/lemon_pynqz1_adc_system.xdc
  Lemon/PYNQ-Z1 AD9226 expansion-header pins.

rtl/src/
  Custom AXI-Lite LED/RGB/button controller and AD9226 capture RTL.

pynq/lemon_pynqz1_capture.py
  Shared Lemon/PYNQ-Z1 overlay and DMA capture helpers.

pynq/lemon_pynqz1_board_adc_test.ipynb
  Generic board validation notebook: overlay load, LED/RGB/button test,
  fake FIFO/DMA, and real ADC capture.

pynq/base_add.bit
pynq/base_add.hwh
  Current generated overlay files copied by the Vivado build.
```

## Build

Run from this workspace:

```powershell
.\scripts\Build-VivadoOverlayWithReport.ps1
```

The build uses:

```text
G:\VIVADO2022\Vivado\2022.1\bin\vivado.bat
```

The generated report is:

```text
VIVADO_OVERLAY_REPORT.md
```

The report includes the PYNQ MMIO address map, register offsets, and exposed
PL pin map. Use it as the handoff sheet before editing notebooks.

## PYNQ Test

Copy or upload these files to the PYNQ Jupyter folder:

```text
pynq/base_add.bit
pynq/base_add.hwh
pynq/lemon_pynqz1_capture.py
pynq/lemon_pynqz1_board_adc_test.ipynb
```

Then run the notebook cells in order:

```text
1. Load overlay and create MMIO/DMA handles
2. Test physical LD0..LD3, LD4/LD5 RGB, and BTN0..BTN3
3. Test fake FIFO/DMA capture path
4. Test real AD9226 capture
```

Cell 2 has been verified on the board with direct XDC/register mapping. Keep
that direct test style for future notebooks; do not add software remapping for
LEDs, RGB LEDs, or buttons.

## Current Board Pin Notes

Board LEDs:

```text
LD0 -> R14
LD1 -> P14
LD2 -> N16
LD3 -> M14
```

Buttons:

```text
BTN0 -> D19
BTN1 -> D20
BTN2 -> L20
BTN3 -> L19
```

RGB LEDs use RGB order:

```text
LD5 R/G/B -> M15/L14/G14
LD4 R/G/B -> N15/G17/L15
```

The board 125 MHz PL clock is H16, but the current overlay uses PS FCLK.
Zynq UART is PS MIO15/MIO14, so it is not constrained in PL XDC.

## History

Old board-specific and experimental material has been moved to the history
folder:

```text
历史残留文件夹/
```

Use that folder only for reference. New development should stay on the generic
Lemon/PYNQ-Z1 ADC files listed above.
