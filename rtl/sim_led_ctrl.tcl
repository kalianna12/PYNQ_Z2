set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set sim_dir [file join $root_dir rtl sim]
set part_name xc7z020clg400-1

file mkdir $sim_dir

create_project -force led_ctrl_axi_sim $sim_dir -part $part_name
add_files -norecurse [file join $root_dir rtl src led_ctrl_axi.v]
add_files -fileset sim_1 -norecurse [file join $root_dir rtl tb tb_led_ctrl_axi.v]
set_property top tb_led_ctrl_axi [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation
close_sim
exit
