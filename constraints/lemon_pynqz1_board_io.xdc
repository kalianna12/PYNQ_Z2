## Lemon ZYNQ / PYNQ-Z1-compatible board IO.
## Verified official-style board pins for first-stage PS-controlled IO.

## 4 single-color LEDs: LD0..LD3
set_property PACKAGE_PIN M14 [get_ports {leds_4bits_tri_o[0]}]
set_property PACKAGE_PIN P14 [get_ports {leds_4bits_tri_o[1]}]
set_property PACKAGE_PIN N16 [get_ports {leds_4bits_tri_o[2]}]
set_property PACKAGE_PIN R14 [get_ports {leds_4bits_tri_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_4bits_tri_o[*]}]
set_property DRIVE 8 [get_ports {leds_4bits_tri_o[*]}]
set_property SLEW SLOW [get_ports {leds_4bits_tri_o[*]}]

## 2 RGB LEDs, bit order per LED is BGR:
## color code 1=BLUE, 2=GREEN, 4=RED.
## LD4: bits [2:0] = B,G,R
set_property PACKAGE_PIN M15 [get_ports {rgb_leds_6bits_tri_o[0]}]
set_property PACKAGE_PIN G14 [get_ports {rgb_leds_6bits_tri_o[1]}]
set_property PACKAGE_PIN L14 [get_ports {rgb_leds_6bits_tri_o[2]}]

## LD5: bits [5:3] = B,G,R
set_property PACKAGE_PIN N15 [get_ports {rgb_leds_6bits_tri_o[3]}]
set_property PACKAGE_PIN G17 [get_ports {rgb_leds_6bits_tri_o[4]}]
set_property PACKAGE_PIN L15 [get_ports {rgb_leds_6bits_tri_o[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {rgb_leds_6bits_tri_o[*]}]
set_property DRIVE 8 [get_ports {rgb_leds_6bits_tri_o[*]}]
set_property SLEW SLOW [get_ports {rgb_leds_6bits_tri_o[*]}]

## 4 push buttons: BTN0..BTN3
set_property PACKAGE_PIN L20 [get_ports {btns_4bits_tri_i[0]}]
set_property PACKAGE_PIN D20 [get_ports {btns_4bits_tri_i[1]}]
set_property PACKAGE_PIN D19 [get_ports {btns_4bits_tri_i[2]}]
set_property PACKAGE_PIN L19 [get_ports {btns_4bits_tri_i[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btns_4bits_tri_i[*]}]
