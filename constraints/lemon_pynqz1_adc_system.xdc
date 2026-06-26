## AD9226 dual-channel interface for Lemon ZYNQ / PYNQ-Z1-compatible board.
##
## This XDC follows the user's physical ribbon/header order.
## The two used columns are the right-side 2x20 expansion header pins:
##
## Even column, row 3 to row 16:
##   ACK A2 A4 A6 A8 A10 A12 BCK B2 B4 B6 B8 B10 B12
##   -> T9 V6 Y9 Y7 T5 U7 V8 V11 Y12 W11 V5 H15 F19 B19
##
## Odd/status column, row 3 to row 16:
##   A1 A3 A5 A7 A9 A11 ORA B1 B3 B5 B7 B9 B11 ORB
##   -> U10 W6 Y8 Y6 U5 V7 W8 V10 Y13 Y11 J15 F16 F20 A20
##
## Do not assign VCC, 3V3, GND, VN, or VP in XDC.
## This is the only active ADC pin constraint file for the Lemon/PYNQ-Z1 flow.

## Channel A clock and data
set_property PACKAGE_PIN T9 [get_ports adc_a_clk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_a_clk]

set_property PACKAGE_PIN U10 [get_ports {adc_a_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[0]}]

set_property PACKAGE_PIN V6 [get_ports {adc_a_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[1]}]

set_property PACKAGE_PIN W6 [get_ports {adc_a_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[2]}]

set_property PACKAGE_PIN Y9 [get_ports {adc_a_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[3]}]

set_property PACKAGE_PIN Y8 [get_ports {adc_a_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[4]}]

set_property PACKAGE_PIN Y7 [get_ports {adc_a_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[5]}]

set_property PACKAGE_PIN Y6 [get_ports {adc_a_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[6]}]

set_property PACKAGE_PIN T5 [get_ports {adc_a_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[7]}]

set_property PACKAGE_PIN U5 [get_ports {adc_a_data[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[8]}]

set_property PACKAGE_PIN U7 [get_ports {adc_a_data[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[9]}]

set_property PACKAGE_PIN V7 [get_ports {adc_a_data[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[10]}]

set_property PACKAGE_PIN V8 [get_ports {adc_a_data[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[11]}]

set_property PACKAGE_PIN W8 [get_ports adc_a_ora]
set_property IOSTANDARD LVCMOS33 [get_ports adc_a_ora]

## Channel B clock and data
set_property PACKAGE_PIN V11 [get_ports adc_b_clk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_b_clk]

set_property PACKAGE_PIN V10 [get_ports {adc_b_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[0]}]

set_property PACKAGE_PIN Y12 [get_ports {adc_b_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[1]}]

set_property PACKAGE_PIN Y13 [get_ports {adc_b_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[2]}]

set_property PACKAGE_PIN W11 [get_ports {adc_b_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[3]}]

set_property PACKAGE_PIN Y11 [get_ports {adc_b_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[4]}]

set_property PACKAGE_PIN V5 [get_ports {adc_b_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[5]}]

set_property PACKAGE_PIN J15 [get_ports {adc_b_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[6]}]

set_property PACKAGE_PIN H15 [get_ports {adc_b_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[7]}]

set_property PACKAGE_PIN F16 [get_ports {adc_b_data[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[8]}]

set_property PACKAGE_PIN F19 [get_ports {adc_b_data[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[9]}]

set_property PACKAGE_PIN F20 [get_ports {adc_b_data[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[10]}]

set_property PACKAGE_PIN B19 [get_ports {adc_b_data[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[11]}]

set_property PACKAGE_PIN A20 [get_ports adc_b_orb]
set_property IOSTANDARD LVCMOS33 [get_ports adc_b_orb]
