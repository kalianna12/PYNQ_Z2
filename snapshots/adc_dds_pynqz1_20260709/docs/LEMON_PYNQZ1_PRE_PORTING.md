# Lemon ZYNQ / PYNQ-Z1 Pre-Porting Notes

Last reviewed: 2026-06-28

This document records the Lemon ZYNQ / PYNQ-Z1 development plan and pin map for
the AD9226 capture and AD9102 waveform overlay. The previous board-specific files have been moved
to the history folder.

The immediate validation goal is:

```text
PYNQ 3.0.1 image
  -> Vivado 2022.1 generated overlay
  -> PS controls PL through AXI-Lite
  -> PS can drive 4 single-color LEDs
  -> PS can drive 2 RGB LEDs, 6 color channels total
  -> PS can read 4 push buttons
  -> AD9226 capture pins are migrated to the Lemon/PYNQ-Z1 expansion headers
  -> AD9102 SPI/trigger/reset pins are exposed without removing ADC or board IO
  -> PS can select sine or SRAM arbitrary waveform, frequency, and amplitude
  -> LED/button/RGB resources remain exposed while the ADC module is present
```

## AD9102 Addition

The AD9102 controller is a separate AXI-Lite peripheral:

```text
ad9102_ctrl_0
base  = 0x40002000
range = 0x1000
```

PL implements SPI mode 0 timing and direct trigger/reset control. PS performs
the high-level register sequence using `pynq/lemon_pynqz1_ad9102.py`.

The external DAC clock changed from 100 MHz to 180 MHz. The DDS tuning word is:

```text
FTW = round(fout * 2^24 / 180000000)
fout_actual = FTW * 180000000 / 2^24
```

This supports the requested 60 MHz sine output. The standard API is limited to
72 MHz (40% of DAC clock) for a practical reconstruction margin; an explicit
advanced option permits values below the 90 MHz Nyquist boundary.

SRAM samples retain the verified STM32 format:

```text
signed 12-bit two's-complement sample
SPI data word = (sample << 2) & 0xFFFF
SRAM address  = 0x6000 + sample_index
```

Pin assignment supplied for this board:

| Signal | PACKAGE_PIN | Direction |
|---|---|---|
| CS_N | U12 | PL output |
| SDO | V13 | PL input |
| SDIO | T15 | PL output |
| SCLK | U17 | PL output |
| CLK_CMOS_IN | U13 | PL monitor input |
| TRIGGER_N | T14 | PL output |
| RESET_N | T16 | PL output |

These pins do not overlap the active AD9226, LED, RGB LED, or button XDC pins.

## Current Project Baseline

The active project is currently built around the following Vivado settings:

```text
part_name  = xc7z020clg400-1
board_part = www.digilentinc.com:pynq-z1:part0:1.0
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

The architecture stays centered on AXI DMA S2MM capture into PS DDR. Board
selection, PS preset, and XDC constraints now target the Lemon/PYNQ-Z1 flow.

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

Important cleanup note:

```text
Old board-specific constraints and notes were moved to 历史残留文件夹/.
Current active constraints are lemon_pynqz1_board_io.xdc and
lemon_pynqz1_adc_system.xdc.
```

## Lemon Board Pin Table From Reference Image

The latest Lemon board resource table gives these package pins. Only resources
that are actually exported by the current top-level RTL should be constrained in
XDC. MIO resources belong to PS configuration, not PL XDC.

```text
UART:
  ZYNQ_TX -> MIO15
  ZYNQ_RX -> MIO14

125M PL clock:
  CLK -> H16

KEY:
  BTN0 -> D19
  BTN1 -> D20
  BTN2 -> L20
  BTN3 -> L19

LED:
  LD0 -> R14
  LD1 -> P14
  LD2 -> N16
  LD3 -> M14

RGB LED:
  LD5_R -> M15
  LD5_G -> L14
  LD5_B -> G14
  LD4_R -> N15
  LD4_G -> G17
  LD4_B -> L15

DIP switch:
  SW1 -> M19
  SW0 -> M20

MIC:
  M_DATA -> G18
  M_CLK  -> F17

AUDIO OUT:
  AUD_PWM_L -> T17
  AUD_PWM_R -> R18

HDMI RX:
  CLK -> N18
  D0  -> V20
  D1  -> T20
  D2  -> N20
  SDA -> U15
  SCL -> U14
  HPD -> T19

HDMI TX:
  CLK -> L16
  D0  -> K17
  D1  -> K19
  D2  -> J18
  SDA -> M18
  SCL -> M17
  HPD -> R19
```

Current overlay note: the design still uses the Zynq PS FCLK for AXI and capture
logic. Therefore the H16 125M PL clock is documented here but not constrained in
`lemon_pynqz1_board_io.xdc` until a top-level `sys_clk` or equivalent port is
added.

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
LD0 / led[0] -> R14
LD1 / led[1] -> P14
LD2 / led[2] -> N16
LD3 / led[3] -> M14
```

Official PYNQ-Z1 board buttons:

```text
BTN0 / btn[0] -> D19
BTN1 / btn[1] -> D20
BTN2 / btn[2] -> L20
BTN3 / btn[3] -> L19
```

Lemon board RGB LEDs from the pin table:

```text
LD5_R -> M15
LD5_G -> L14
LD5_B -> G14
LD4_R -> N15
LD4_G -> G17
LD4_B -> L15
```

The final physical RGB pin order follows the Lemon reference image: both RGB
LEDs use bit order `R G B`. The register field names are still historical, so
the software helper keeps the LD4/LD5 field swap.

Register field `ld4_color` controls the physical board LED `LD5`, with bit
order `R G B`.

Register field `ld5_color` controls the physical board LED `LD4`, with bit
order `R G B`.

Physical `LD4`, bit order `R G B`:

```text
OFF     = 0b000
RED     = 0b001
GREEN   = 0b010
BLUE    = 0b100
YELLOW  = 0b011
MAGENTA = 0b101
CYAN    = 0b110
WHITE   = 0b111
```

Physical `LD5`, bit order `R G B`:

```text
OFF     = 0b000
RED     = 0b001
GREEN   = 0b010
BLUE    = 0b100
YELLOW  = 0b011
MAGENTA = 0b101
CYAN    = 0b110
WHITE   = 0b111
```

Notebook code must expose a physical-board helper:

```python
def set_rgb(led_mask=0, ld4="OFF", ld5="OFF"):
    return set_board_io(
        led_mask=led_mask,
        ld4_color=encode_physical_ld5(ld5),
        ld5_color=encode_physical_ld4(ld4),
    )
```

This example is verified correct:

```python
set_rgb(led_mask=0b1111, ld4="BLUE", ld5="GREEN")
```

Expected physical result:

```text
LD4 = blue
LD5 = green
LED0..LED3 = on
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

Cell 2 of the generic notebook has verified that LED, RGB, and button bits now
match the XDC directly. Do not add software helper remapping tables for these
signals in future notebooks.

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
set_property PACKAGE_PIN R14 [get_ports {leds_4bits_tri_o[0]}]
set_property PACKAGE_PIN P14 [get_ports {leds_4bits_tri_o[1]}]
set_property PACKAGE_PIN N16 [get_ports {leds_4bits_tri_o[2]}]
set_property PACKAGE_PIN M14 [get_ports {leds_4bits_tri_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_4bits_tri_o[*]}]

set_property PACKAGE_PIN M15 [get_ports {rgb_leds_6bits_tri_o[0]}]
set_property PACKAGE_PIN L14 [get_ports {rgb_leds_6bits_tri_o[1]}]
set_property PACKAGE_PIN G14 [get_ports {rgb_leds_6bits_tri_o[2]}]
set_property PACKAGE_PIN N15 [get_ports {rgb_leds_6bits_tri_o[3]}]
set_property PACKAGE_PIN G17 [get_ports {rgb_leds_6bits_tri_o[4]}]
set_property PACKAGE_PIN L15 [get_ports {rgb_leds_6bits_tri_o[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgb_leds_6bits_tri_o[*]}]

set_property PACKAGE_PIN D19 [get_ports {btns_4bits_tri_i[0]}]
set_property PACKAGE_PIN D20 [get_ports {btns_4bits_tri_i[1]}]
set_property PACKAGE_PIN L20 [get_ports {btns_4bits_tri_i[2]}]
set_property PACKAGE_PIN L19 [get_ports {btns_4bits_tri_i[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btns_4bits_tri_i[*]}]
```

This test proves:

- The PYNQ 3.0.1 image can load the Vivado 2022.1 bit/hwh pair.
- PS AXI-Lite access works.
- Board-level single-color LED, RGB LED, and button constraints are correct.
- The PL fabric remains available while the ADC module is also present.

Verified board result on 2026-06-27:

```text
Generic notebook Cell 2 passed with direct XDC/register mapping.
LD0..LD3, LD4 RGB, LD5 RGB, and BTN0..BTN3 all behaved correctly.
```

Use this direct mapping from now on. Do not add software-side LED/button
remapping tables such as `LED_PHYS_TO_MASK` or `BTN_PHYS_TO_MASK`; those hide
XDC mistakes and are not suitable for board validation.

Direct mapping that is now accepted as correct:

```text
LED_VALUE bit0 -> physical LD0 -> R14
LED_VALUE bit1 -> physical LD1 -> P14
LED_VALUE bit2 -> physical LD2 -> N16
LED_VALUE bit3 -> physical LD3 -> M14

LED_VALUE bits[6:4] -> physical LD5 R/G/B -> M15/L14/G14
LED_VALUE bits[9:7] -> physical LD4 R/G/B -> N15/G17/L15

LED_STATUS bit10 -> physical BTN0 -> D19
LED_STATUS bit11 -> physical BTN1 -> D20
LED_STATUS bit12 -> physical BTN2 -> L20
LED_STATUS bit13 -> physical BTN3 -> L19
```

## PYNQ Fixed Address Contract

Notebook code must use the fixed physical addresses from `base_add.hwh` instead
of guessing write methods from `overlay.<ip_name>`. Custom RTL IP can appear as
hierarchy/IPMap objects in PYNQ, so direct `.write()` on the overlay attribute is
not reliable.

Current address map:

```text
led_ctrl_0    base 0x40000000, high 0x40000FFF, range 0x1000
adc_capture_0 base 0x40001000, high 0x40001FFF, range 0x1000
ad9102_ctrl_0 base 0x40002000, high 0x40002FFF, range 0x1000
axi_dma_0     base 0x40400000, high 0x4040FFFF, range 0x10000
```

Use these bindings in notebooks:

```python
from pynq import Overlay, MMIO

overlay = Overlay("base_add.bit")
led_ip = MMIO(0x40000000, 0x1000)
adc_ip = MMIO(0x40001000, 0x1000)
dma = overlay.axi_dma_0
```

The Vivado report generator must list this address map, the register offsets,
and all exposed XDC pins. Treat `VIVADO_OVERLAY_REPORT.md` as the handoff sheet
for PYNQ-side code.

LED/RGB/button register offsets:

```text
LED_CTRL   0x00
LED_VALUE  0x08
LED_STATUS 0x0C
```

`LED_VALUE` direct bit layout:

```text
bits[3:0] -> LD0, LD1, LD2, LD3
bits[6:4] -> physical LD5 R, G, B
bits[9:7] -> physical LD4 R, G, B
```

`LED_STATUS` direct bit layout:

```text
bits[3:0]   -> current LD0..LD3 value
bits[9:4]   -> current RGB value
bits[13:10] -> BTN0, BTN1, BTN2, BTN3
```

ADC capture register offsets used by the generic notebook:

```text
CTRL                  0x00
STATUS                0x04
SAMPLE_COUNT          0x08
ADC_HALF              0x0C
SAMPLE_DELAY          0x10
DECIMATION            0x14
CHANNEL_MASK          0x18
CAPTURE_MODE          0x1C
TRIGGER_MODE          0x20
PRE_DELAY             0x24
BUFFER_SELECT         0x28
LATEST_A              0x2C
LATEST_B              0x30
SAMPLE_COUNTER        0x34
FIFO_LEVEL            0x38
ERROR_FLAGS           0x3C
VERSION               0x44
SAVED_COUNTER         0x48
LAST_AXIS_WORD        0x4C
DEBUG_STATE           0x50
AXIS_SENT_COUNT       0x54
AXIS_STALL_COUNT      0x58
TLAST_COUNT           0x5C
FIFO_BACKPRESSURE     0x60
DROPPED_SAMPLE_COUNT  0x64
CAPTURE_DONE_LATCHED  0x68
CORE_DONE             0x6C
```

The current RTL uses fixed dual-channel 62.5 MSPS physical sampling:

```text
ADC A clock = 62.5 MHz
ADC B clock = 62.5 MHz
clock phase = identical at the two FPGA outputs
saved rate  = 62.5 MSPS / DECIMATION
```

`ADC_HALF` and `SAMPLE_DELAY` are legacy-compatible registers and do not alter
the physical clock or capture edge. Low-frequency tests use `DECIMATION`; for
example, `3125` produces a 20 kSPS saved stream for a 1 kHz input. The ADC XDC
models the AD9226 output-delay window and selects the following-cycle capture
edge explicitly.

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
Use the Lemon-specific ADC XDC.
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
7. Test real ADC capture at fixed 62.5 MSPS, using decimation for a lower saved rate.
8. Use the generic ADC notebook/helper as the continuing bring-up path.

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
