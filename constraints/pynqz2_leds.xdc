set led0 [get_ports -quiet {leds_4bits_tri_o[0]}]
if {[llength $led0] == 0} { set led0 [get_ports -quiet {leds_4bits_tri_o_0[0]}] }
set led1 [get_ports -quiet {leds_4bits_tri_o[1]}]
if {[llength $led1] == 0} { set led1 [get_ports -quiet {leds_4bits_tri_o_0[1]}] }
set led2 [get_ports -quiet {leds_4bits_tri_o[2]}]
if {[llength $led2] == 0} { set led2 [get_ports -quiet {leds_4bits_tri_o_0[2]}] }
set led3 [get_ports -quiet {leds_4bits_tri_o[3]}]
if {[llength $led3] == 0} { set led3 [get_ports -quiet {leds_4bits_tri_o_0[3]}] }

set_property PACKAGE_PIN R14 $led0
set_property PACKAGE_PIN P14 $led1
set_property PACKAGE_PIN N16 $led2
set_property PACKAGE_PIN M14 $led3

set_property IOSTANDARD LVCMOS33 $led0
set_property IOSTANDARD LVCMOS33 $led1
set_property IOSTANDARD LVCMOS33 $led2
set_property IOSTANDARD LVCMOS33 $led3
