## AD9226 dual-channel interface for PYNQ-Z2
## Keep these PACKAGE_PIN values as confirmed for the RPi header swapped mapping.

## Channel A clock and data
set_property PACKAGE_PIN V6 [get_ports adc_a_clk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_a_clk]

set_property PACKAGE_PIN W18 [get_ports {adc_a_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[0]}]

## A2 hardware Y19 -> XDC Y6
set_property PACKAGE_PIN Y6 [get_ports {adc_a_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[1]}]

set_property PACKAGE_PIN W19 [get_ports {adc_a_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[2]}]

set_property PACKAGE_PIN C20 [get_ports {adc_a_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[3]}]

## A5 hardware V6 -> XDC Y18
set_property PACKAGE_PIN Y18 [get_ports {adc_a_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[4]}]

set_property PACKAGE_PIN W6 [get_ports {adc_a_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[5]}]

set_property PACKAGE_PIN U7 [get_ports {adc_a_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[6]}]

## A8 hardware U18 -> XDC Y7
set_property PACKAGE_PIN Y7 [get_ports {adc_a_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[7]}]

set_property PACKAGE_PIN V7 [get_ports {adc_a_data[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[8]}]

## A10 hardware U19 -> XDC F20
set_property PACKAGE_PIN F20 [get_ports {adc_a_data[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[9]}]

set_property PACKAGE_PIN U8 [get_ports {adc_a_data[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[10]}]

set_property PACKAGE_PIN F19 [get_ports {adc_a_data[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_a_data[11]}]

set_property PACKAGE_PIN V8 [get_ports adc_a_ora]
set_property IOSTANDARD LVCMOS33 [get_ports adc_a_ora]

## Channel B clock and data
## BCK hardware F20 -> XDC U19
set_property PACKAGE_PIN U19 [get_ports adc_b_clk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_b_clk]

set_property PACKAGE_PIN V10 [get_ports {adc_b_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[0]}]

set_property PACKAGE_PIN Y17 [get_ports {adc_b_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[1]}]

set_property PACKAGE_PIN W10 [get_ports {adc_b_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[2]}]

set_property PACKAGE_PIN B20 [get_ports {adc_b_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[3]}]

set_property PACKAGE_PIN Y16 [get_ports {adc_b_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[4]}]

set_property PACKAGE_PIN B19 [get_ports {adc_b_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[5]}]

## B7 hardware Y6 -> XDC Y19
set_property PACKAGE_PIN Y19 [get_ports {adc_b_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[6]}]

set_property PACKAGE_PIN A20 [get_ports {adc_b_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[7]}]

## B9 hardware Y7 -> XDC U18
set_property PACKAGE_PIN U18 [get_ports {adc_b_data[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[8]}]

set_property PACKAGE_PIN Y9 [get_ports {adc_b_data[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[9]}]

set_property PACKAGE_PIN W8 [get_ports {adc_b_data[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[10]}]

set_property PACKAGE_PIN W9 [get_ports {adc_b_data[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_b_data[11]}]

## B13 temporarily used as ORB; confirm AD9226 module silk screen/schematic.
set_property PACKAGE_PIN Y8 [get_ports adc_b_orb]
set_property IOSTANDARD LVCMOS33 [get_ports adc_b_orb]
