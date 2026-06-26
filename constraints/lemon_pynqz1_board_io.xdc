## Lemon ZYNQ / PYNQ-Z1-compatible board IO.
## Verified official-style board pins for first-stage PS-controlled IO.
## Pin source: Lemon board reference table provided on 2026-06-27.
##
## Note: board CLK is H16, but this overlay currently uses PS FCLK and has no
## top-level sys_clk port in this XDC. ZYNQ UART is PS MIO15/MIO14, not PL XDC.

## 4 single-color LEDs: LD0..LD3
set_property PACKAGE_PIN R14 [get_ports {leds_4bits_tri_o[0]}]
set_property PACKAGE_PIN P14 [get_ports {leds_4bits_tri_o[1]}]
set_property PACKAGE_PIN N16 [get_ports {leds_4bits_tri_o[2]}]
set_property PACKAGE_PIN M14 [get_ports {leds_4bits_tri_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_4bits_tri_o[*]}]
set_property DRIVE 8 [get_ports {leds_4bits_tri_o[*]}]
set_property SLEW SLOW [get_ports {leds_4bits_tri_o[*]}]

## 2 RGB LEDs.
## Hardware table:
##   LD5 R/G/B = M15/L14/G14
##   LD4 R/G/B = N15/G17/L15
##
## Register field led_value[6:4] is named ld4_color in software, but it drives
## physical LD5 as R,G,B:
set_property PACKAGE_PIN M15 [get_ports {rgb_leds_6bits_tri_o[0]}]
set_property PACKAGE_PIN L14 [get_ports {rgb_leds_6bits_tri_o[1]}]
set_property PACKAGE_PIN G14 [get_ports {rgb_leds_6bits_tri_o[2]}]

## Register field led_value[9:7] is named ld5_color in software, but it drives
## physical LD4 as R,G,B:
set_property PACKAGE_PIN N15 [get_ports {rgb_leds_6bits_tri_o[3]}]
set_property PACKAGE_PIN G17 [get_ports {rgb_leds_6bits_tri_o[4]}]
set_property PACKAGE_PIN L15 [get_ports {rgb_leds_6bits_tri_o[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {rgb_leds_6bits_tri_o[*]}]
set_property DRIVE 8 [get_ports {rgb_leds_6bits_tri_o[*]}]
set_property SLEW SLOW [get_ports {rgb_leds_6bits_tri_o[*]}]

## 4 push buttons: BTN0..BTN3
set_property PACKAGE_PIN D19 [get_ports {btns_4bits_tri_i[0]}]
set_property PACKAGE_PIN D20 [get_ports {btns_4bits_tri_i[1]}]
set_property PACKAGE_PIN L20 [get_ports {btns_4bits_tri_i[2]}]
set_property PACKAGE_PIN L19 [get_ports {btns_4bits_tri_i[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btns_4bits_tri_i[*]}]
