# Lemon PYNQ-Z1 AD9226 + AD9102 Overlay

This workspace is the cleaned Lemon/PYNQ-Z1 development tree for AD9226
capture, AD9102 waveform generation, and board IO validation.

The current target is:

```text
Board      : Lemon ZYNQ / PYNQ-Z1-compatible board
FPGA       : XC7Z020 CLG400
Vivado     : 2022.1
PYNQ image : 3.0.1
Overlay    : board IO + AD9226 capture/DMA + AD9102 SPI control
```

## Active Files

```text
vivado/build.tcl
  Creates the Vivado block design and copies base_add.bit/base_add.hwh to pynq/.

constraints/lemon_pynqz1_board_io.xdc
  Lemon/PYNQ-Z1 LED, RGB LED, and button pins.

constraints/lemon_pynqz1_adc_system.xdc
  Lemon/PYNQ-Z1 AD9226 expansion-header pins.

constraints/lemon_pynqz1_ad9102.xdc
  AD9102 SPI, trigger, reset, and 180 MHz clock-monitor pins.

rtl/src/
  AXI-Lite board IO, AD9226 capture, and AD9102 SPI controller RTL.

pynq/lemon_pynqz1_capture.py
  Shared Lemon/PYNQ-Z1 overlay and DMA capture helpers.

pynq/lemon_pynqz1_board_adc_test.ipynb
  Generic board validation notebook: overlay load, LED/RGB/button test,
  fake FIFO/DMA, and real ADC capture.

pynq/lemon_pynqz1_ad9102.py
  AD9102 driver using fixed MMIO at 0x40002000. It preserves the verified
  STM32 register order and signed SRAM sample format.

pynq/lemon_pynqz1_adc_dds_test.ipynb
  AD9102 sine/60 MHz/arbitrary-wave tests plus simultaneous real ADC capture.

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

## Fixed ADC Sampling

Both AD9226 channels run from the same MMCM-generated 62.5 MHz clock. The two
clock outputs are launched in phase, and both 12-bit buses are captured in
input IOB registers on a separately phased MMCM edge. The XDC models the
AD9226 3.5 ns to 7.0 ns output delay and checks all 24 data inputs.

`ADC_HALF` and `SAMPLE_DELAY` remain for register compatibility, but no longer
change the physical ADC clock or capture phase. Use `DECIMATION=N` to save one
sample for every N physical conversions:

```text
physical conversion rate = 62.5 MSPS
saved sample rate         = 62.5 MSPS / DECIMATION
```

For example, `DECIMATION=3125` gives 20 kSPS for viewing a 1 kHz waveform.

## PYNQ Test

Copy or upload these files to the PYNQ Jupyter folder:

```text
pynq/base_add.bit
pynq/base_add.hwh
pynq/lemon_pynqz1_capture.py
pynq/lemon_pynqz1_board_adc_test.ipynb
pynq/lemon_pynqz1_ad9102.py
pynq/lemon_pynqz1_adc_dds_test.ipynb
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

For DDS and simultaneous ADC/DDS validation, run:

```text
pynq/lemon_pynqz1_adc_dds_test.ipynb
```

## AD9102

The fixed PS address is:

```text
ad9102_ctrl_0 -> MMIO(0x40002000, 0x1000)
```

The module clock is 180 MHz. DDS frequency uses:

```text
FTW = round(frequency_hz * 2^24 / 180000000)
```

The normal Python API allows 1 Hz through 72 MHz. Frequencies above 72 MHz and
below the 90 MHz Nyquist boundary require the explicit advanced flag.

For SRAM arbitrary waveforms, `configure_arbitrary(samples, freq_hz,
amplitude)` resamples one source period to `round(180 MHz / freq_hz)` SRAM
points. Therefore the achievable frequency is quantized by the integer sample
count; the method returns the actual value.

```text
CS_N         U12
SDO          V13
SDIO         T15
SCLK         U17
CLK_CMOS_IN  U13
TRIGGER_N    T14
RESET_N      T16
```

`CLK_CMOS_IN` is currently treated as a monitor input to PL; the 180 MHz
oscillator clocks the AD9102 directly. Do not drive this net from PL unless the
module schematic proves that the header pin is an external clock input.

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
