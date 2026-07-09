set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set dcp_file [file join $root_dir build vivado base_add_overlay.runs impl_1 system_wrapper_routed.dcp]

open_checkpoint $dcp_file

puts "=== CLOCKS ==="
foreach item [get_clocks *] {
    puts "[get_property NAME $item] period=[get_property PERIOD $item]"
}

puts "=== CLKOUT1 BUFFER PINS ==="
foreach item [get_pins -hier -filter {NAME =~ *adc_clock_wizard_0*clkout1_buf/O}] {
    puts "[get_property NAME $item] clocks=[get_clocks -quiet -of_objects $item]"
}

puts "=== ADC OUTPUT PORT CLOCKS ==="
foreach port_name {adc_a_clk adc_b_clk} {
    set item [get_ports $port_name]
    puts "$port_name clocks=[get_clocks -quiet -of_objects $item]"
}

puts "=== ADC INPUT TIMING ==="
report_timing -from [get_ports {adc_a_data[*] adc_b_data[*]}] \
    -to [get_pins -hier -filter {NAME =~ */adc_*_capture_reg*/D}] \
    -delay_type max -max_paths 4
report_timing -from [get_ports {adc_a_data[*] adc_b_data[*]}] \
    -to [get_pins -hier -filter {NAME =~ */adc_*_capture_reg*/D}] \
    -delay_type min -max_paths 4

close_design
exit
