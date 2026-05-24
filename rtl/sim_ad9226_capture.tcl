set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set sim_dir [file join $root_dir rtl sim]
set part_name xc7z020clg400-1

file mkdir $sim_dir

create_project -force ad9226_capture_sim $sim_dir -part $part_name
add_files -norecurse [file join $root_dir rtl src adc_ctrl_axi.v]
add_files -norecurse [file join $root_dir rtl src ad9226_capture_core.v]
add_files -norecurse [file join $root_dir rtl src adc_sample_fifo.v]
add_files -fileset sim_1 -norecurse [file join $root_dir rtl tb tb_ad9226_capture_chain.v]
set_property top tb_ad9226_capture_chain [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation
close_sim
exit
