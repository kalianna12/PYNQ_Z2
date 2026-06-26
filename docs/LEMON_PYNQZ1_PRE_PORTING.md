# Lemon ZYNQ / PYNQ-Z1 Pre-Porting Notes

Last reviewed: 2026-06-26

This document records the pre-porting plan for moving the current
PYNQ-Z2-oriented AD9226 capture overlay to the Lemon ZYNQ board that is intended
to behave like a PYNQ-Z1-compatible board.

The immediate validation goal is:

```text
PYNQ 3.0.1 image
  -> Vivado 2022.1 generated overlay
  -> PS controls PL through AXI-Lite
  -> PS can drive 4 single-color LEDs
  -> PS can drive 2 RGB LEDs, 6 color channels total
  -> PS can read 4 push buttons
  -> AD9226 capture pins are migrated to the Lemon/PYNQ-Z1 expansion headers
  -> LED/button/RGB resources remain exposed while the ADC module is present
```

## Current Project Baseline

The active project is currently built around the following Vivado settings:

```text
part_name  = xc7z020clg400-1
board_part = tul.com.tw:pynq-z2:part0:1.0
```

The current overlay path is:

```text
AD9226 pins or RTL fake stream
  -> adc_capture_0 / M_AXIS_SAMPLE
  -> axis_data_fifo_0
  -> axi_dma_0 S2MM
  -> PS DDR through S_AXI_HP0
  -> PYNQ Python uint32 buffer
```

The architecture can stay the same after the board migration. The parts that
must change are the board selection, PS preset, and XDC constraints.

## Tool Version Decision

The Lemon site notes that its base and PetaLinux projects are based on
Vivado 2018.3, while PYNQ development for the PYNQ 3.0 image needs
Vivado 2022.1.

For this project, use Vivado 2022.1 because the target SD card image is
PYNQ 3.0.1. This reduces risk in PYNQ `.hwh` parsing, IP version matching, and
overlay loading.

The old Vivado 2018.2/2018.3 flow should be treated as reference material only
for schematics, PS configuration, and board pin naming.

## Board Relationship

The Lemon board is close to the official PYNQ-Z1 class of boards:

- Zynq-7020 CLG400 package.
- PS-side DDR, SD, Ethernet, USB, UART, QSPI, and boot resources are fixed
  board resources.
- PL banks 13, 34, and 35 are powered at 3.3 V according to the Lemon
  schematic.
- Two 2x20 expansion headers expose many PL GPIO pins.
- A 1x10 analog/XADC header exposes `VN`, `VP`, and six labeled analog/digital
  pins.
- Board resources include LEDs, RGB LEDs, 4 push buttons, 2 DIP switches,
  HDMI RX/TX, audio, and a PL clock.

Important difference from the current project:

```text
Current project constraints target PYNQ-Z2.
Lemon/PYNQ-Z1 needs its own XDC.
```

Do not reuse `constraints/pynq_adc_system.xdc` blindly on Lemon. That file is
for the current PYNQ-Z2 wiring.

## Official PYNQ-Z1 / Verified Board Resource Pins

The board LED and button pins are treated as verified official PYNQ-Z1-style
resources for this migration. Use these pins for the first-stage PS-controlled
IO validation.

The local Vivado board file for official PYNQ-Z1 records these same useful pins:

```text
G:\Xilinx\Vivado\2018.2\data\boards\board_files\pynq-z1\1.0\part0_pins.xml
```

Official PYNQ-Z1 board part name observed from the local board files:

```text
www.digilentinc.com:pynq-z1:part0:1.0
```

Official PYNQ-Z1 board LEDs:

```text
LD0 / led[0] -> M14
LD1 / led[1] -> P14
LD2 / led[2] -> N16
LD3 / led[3] -> R14
```

Official PYNQ-Z1 board buttons:

```text
BTN0 / btn[0] -> L20
BTN1 / btn[1] -> D20
BTN2 / btn[2] -> D19
BTN3 / btn[3] -> L19
```

Lemon board RGB LEDs from the schematic summary:

```text
LD4_B / rgb[0] -> M15
LD4_G / rgb[1] -> G14
LD4_R / rgb[2] -> L14
LD5_B / rgb[3] -> N15
LD5_G / rgb[4] -> G17
LD5_R / rgb[5] -> L15
```

The verified RGB color code for each 3-bit RGB LED is:

```python
COLOR_NAME = {
    0: "OFF",
    1: "BLUE",
    2: "GREEN",
    3: "CYAN",
    4: "RED",
    5: "MAGENTA",
    6: "YELLOW",
    7: "WHITE",
}
```

In plain words:

```text
0 -> off
1 -> blue
2 -> green
3 -> cyan
4 -> red
5 -> magenta
6 -> yellow
7 -> white
```

This means the per-RGB-LED bit order used by PS software should be:

```text
bit[0] = blue
bit[1] = green
bit[2] = red
```

Official PYNQ-Z1 DIP switches:

```text
sws_2bits_tri_i[0] -> M20
sws_2bits_tri_i[1] -> M19
```

Official PYNQ-Z1 PL clock:

```text
sys_clk -> H16
```

The DIP switches are not part of the first-stage requirement, but the pins are
kept here for later board checks.

If later testing finds LED/RGB polarity is inverted, fix the PS-side test code
or add an inversion option in the LED GPIO register layer. Do not move pins
unless the schematic or board test proves the pin assignment is wrong.

## Expansion Header Availability

Power and ground pins must not be constrained in XDC:

```text
VCC, 3V3, GND
```

The analog pins `VN` and `VP` must not be used as normal LVCMOS33 GPIO. Treat
them as XADC analog pins unless the schematic explicitly proves another use.

For normal 3.3 V PL IO, the common XDC form is:

```xdc
set_property PACKAGE_PIN <PACKAGE_PIN> [get_ports {<port_name>}]
set_property IOSTANDARD LVCMOS33 [get_ports {<port_name>}]
```

The user's file below is the working Lemon/PYNQ-Z1 expansion-pin map for ADC
assignment:

```text
G:\LEMON_FPGA_PYNQZ1\PYNQ_Z1_扩展排针_XDC引脚分配表.md
```

The right-side pins starting with:

```text
W9, U8, U10, W6, ...
```

are expansion-header PL package pins. They are not HDL signal names. Assign an
HDL port to one of them only once.

## First-Stage PS-Controlled IO Requirement

The first Lemon validation overlay should expose these board IO resources to PS:

```text
4 single-color LEDs -> PS writable output bits
2 RGB LEDs          -> PS writable output bits, 6 channels total
4 buttons           -> PS readable input bits
```

The PS must be able to directly verify every bit:

```text
write led bit 0..3        -> observe LD0..LD3
write rgb bit 0..5        -> observe LD4/LD5 R/G/B channels
read button bit 0..3      -> observe BTN0..BTN3 state changes
```

Recommended first-stage XDC signal naming:

```xdc
set_property PACKAGE_PIN M14 [get_ports {leds_4bits_tri_o[0]}]
set_property PACKAGE_PIN P14 [get_ports {leds_4bits_tri_o[1]}]
set_property PACKAGE_PIN N16 [get_ports {leds_4bits_tri_o[2]}]
set_property PACKAGE_PIN R14 [get_ports {leds_4bits_tri_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_4bits_tri_o[*]}]

set_property PACKAGE_PIN M15 [get_ports {rgb_leds_6bits_tri_o[0]}]
set_property PACKAGE_PIN G14 [get_ports {rgb_leds_6bits_tri_o[1]}]
set_property PACKAGE_PIN L14 [get_ports {rgb_leds_6bits_tri_o[2]}]
set_property PACKAGE_PIN N15 [get_ports {rgb_leds_6bits_tri_o[3]}]
set_property PACKAGE_PIN G17 [get_ports {rgb_leds_6bits_tri_o[4]}]
set_property PACKAGE_PIN L15 [get_ports {rgb_leds_6bits_tri_o[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_leds_6bits_tri_o[*]}]

set_property PACKAGE_PIN L20 [get_ports {btns_4bits_tri_i[0]}]
set_property PACKAGE_PIN D20 [get_ports {btns_4bits_tri_i[1]}]
set_property PACKAGE_PIN D19 [get_ports {btns_4bits_tri_i[2]}]
set_property PACKAGE_PIN L19 [get_ports {btns_4bits_tri_i[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btns_4bits_tri_i[*]}]
```

This test proves:

- The PYNQ 3.0.1 image can load the Vivado 2022.1 bit/hwh pair.
- PS AXI-Lite access works.
- Board-level single-color LED, RGB LED, and button constraints are correct.
- The PL fabric remains available while the ADC module is also present.

## PL Pin Conflict Rules

The PL can only use pins that are not already claimed by another top-level port
in the same bitstream.

The PL cannot take over PS fixed resources:

```text
PS DDR
PS SD card
PS Ethernet
PS USB
PS QSPI
PS UART MIO
JTAG/config pins
```

HDMI, audio, LEDs, buttons, DIP switches, and expansion pins are PL-side board
resources. If a design does not instantiate HDMI/audio logic and does not
constrain those pins, they are logically unused by the bitstream. However, they
are still physically connected to board circuitry, so prefer expansion-header
pins for the ADC rather than HDMI/audio pins.

## ADC Porting Requirement

The current ADC RTL expects these external ports:

```text
adc_a_clk
adc_b_clk
adc_a_ora
adc_b_orb
adc_a_data[11:0]
adc_b_data[11:0]
```

That is 28 PL signals:

```text
2 clocks + 2 overflow/status + 24 data
```

Porting rule:

```text
Create a Lemon-specific ADC XDC.
Do not edit the PYNQ-Z2 XDC in place.
Keep LED/button/RGB XDC active at the same time.
```

Recommended new file:

```text
constraints/lemon_pynqz1_adc_system.xdc
```

The ADC should be assigned to expansion-header PL pins that are:

- Ordinary 3.3 V digital IO.
- Not `VCC`, `3V3`, `GND`, `VN`, or `VP`.
- Not already used by single-color LEDs, RGB LEDs, buttons, or any other board resource.
- Preferably in compact groups to reduce routing spread.
- Taken from `G:\LEMON_FPGA_PYNQZ1\PYNQ_Z1_扩展排针_XDC引脚分配表.md`.
- Confirmed against the actual ADC wiring harness before final timing/signoff.

The first migrated ADC XDC may reuse the current known-good AD9226 signal order
from the existing project, but the target package pins must come from the Lemon
expansion-header table. The ADC migration is not a separate future project; it
is part of the Lemon overlay requirement as long as the board LEDs, RGB LEDs,
and buttons remain exposed to PS.

The current Lemon ADC ribbon/header order is:

```text
Even column, row 3 to row 16:
ACK A2 A4 A6 A8 A10 A12 BCK B2 B4 B6 B8 B10 B12
-> T9 V6 Y9 Y7 T5 U7 V8 V11 Y12 W11 V5 H15 F19 B19

Odd/status column, row 3 to row 16:
A1 A3 A5 A7 A9 A11 ORA B1 B3 B5 B7 B9 B11 ORB
-> U10 W6 Y8 Y6 U5 V7 W8 V10 Y13 Y11 J15 F16 F20 A20
```

That corresponds to these RTL ports:

```text
adc_a_clk      -> T9
adc_a_data[0]  -> U10    adc_a_data[1]  -> V6
adc_a_data[2]  -> W6     adc_a_data[3]  -> Y9
adc_a_data[4]  -> Y8     adc_a_data[5]  -> Y7
adc_a_data[6]  -> Y6     adc_a_data[7]  -> T5
adc_a_data[8]  -> U5     adc_a_data[9]  -> U7
adc_a_data[10] -> V7     adc_a_data[11] -> V8
adc_a_ora      -> W8

adc_b_clk      -> V11
adc_b_data[0]  -> V10    adc_b_data[1]  -> Y12
adc_b_data[2]  -> Y13    adc_b_data[3]  -> W11
adc_b_data[4]  -> Y11    adc_b_data[5]  -> V5
adc_b_data[6]  -> J15    adc_b_data[7]  -> H15
adc_b_data[8]  -> F16    adc_b_data[9]  -> F19
adc_b_data[10] -> F20    adc_b_data[11] -> B19
adc_b_orb      -> A20
```

## Vivado Changes Expected

For a PYNQ 3.0.1 target, build with Vivado 2022.1 and update the Tcl flow:

```text
board_part -> PYNQ-Z1-compatible board part or part-only flow
LED XDC    -> Lemon/PYNQ-Z1 LED/RGB/button XDC
ADC XDC    -> Lemon ADC XDC
PS preset  -> PYNQ-Z1/Lemon-compatible PS configuration
```

The existing `part_name` can remain:

```text
xc7z020clg400-1
```

If the Lemon board file is not installed in Vivado 2022.1, use the part-only
flow and explicitly configure PS7 according to the Lemon/PYNQ-Z1 base design.

## Bring-Up Checklist

1. Install Vivado 2022.1.
2. Build an overlay exposing 4 single-color LEDs, 2 RGB LEDs, 4 buttons, and the ADC module.
3. Load the overlay on PYNQ 3.0.1.
4. Write LED/RGB AXI registers from Jupyter and verify all 10 output bits.
5. Read button AXI registers from Jupyter and verify all 4 input bits.
6. Test `capture_mode = 2` fake stream through DMA.
7. Test real ADC capture at a slow/known-good rate.
8. Run the AFSK notebook/service after the waveform is correct.

## Notes for the User's Header Table

The table supplied by the user is suitable for generating XDC constraints as
long as these meanings are preserved:

- `T12`, `U12`, `W9`, `U8`, etc. are FPGA package pins.
- They are not HDL names.
- A HDL top-level port must be assigned to exactly one package pin.
- A package pin must not be assigned to two different top-level ports.
- `LVCMOS33` is acceptable only for confirmed 3.3 V PL GPIO pins.
- ADC clocks, external clocks, and high-speed buses may need extra timing
  constraints beyond `PACKAGE_PIN` and `IOSTANDARD`.

The immediate recommendation is to reserve official board LED/button pins for
PS control validation and reserve expansion-header pins for ADC experiments.
