set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set project_name base_add_overlay
set design_name system
set part_name xc7z020clg400-1
set board_part tul.com.tw:pynq-z2:part0:1.0

set build_dir [file join $root_dir build vivado]
set pynq_dir [file join $root_dir pynq]
set hls_ip_repo [file join $root_dir hls base_add_prj solution1 impl ip]

file mkdir $build_dir
file mkdir $pynq_dir

if {![file exists $hls_ip_repo]} {
    puts "ERROR: HLS IP repo not found: $hls_ip_repo"
    puts "Run VS Code task: FPGA: 1 Build HLS IP"
    exit 1
}

create_project -force $project_name $build_dir -part $part_name
set_property board_part $board_part [current_project]
set_property ip_repo_paths [list $hls_ip_repo] [current_project]
update_ip_catalog

create_bd_design $design_name

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {1}] [get_bd_cells processing_system7_0]

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR"} \
    [get_bd_cells processing_system7_0]

set hls_ipdefs [get_ipdefs -all *base_add*]
if {[llength $hls_ipdefs] == 0} {
    puts "ERROR: Could not find HLS IP named base_add in $hls_ip_repo"
    exit 1
}

set hls_vlnv [lindex $hls_ipdefs 0]
create_bd_cell -type ip -vlnv $hls_vlnv base_add_0

set ctrl_pin [get_bd_intf_pins -quiet base_add_0/s_axi_CTRL]
if {[llength $ctrl_pin] == 0} {
    set ctrl_pin [get_bd_intf_pins -quiet base_add_0/S_AXI_CTRL]
}
if {[llength $ctrl_pin] == 0} {
    puts "ERROR: Could not find AXI-Lite control interface on base_add_0"
    exit 1
}

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto"} \
    $ctrl_pin

set m_axi_pin [get_bd_intf_pins -quiet base_add_0/m_axi_GMEM]
if {[llength $m_axi_pin] == 0} {
    set m_axi_pin [get_bd_intf_pins -quiet base_add_0/M_AXI_GMEM]
}
if {[llength $m_axi_pin] == 0} {
    puts "ERROR: Could not find AXI master interface m_axi_GMEM on base_add_0"
    exit 1
}

set hp0_pin [get_bd_intf_pins -quiet processing_system7_0/S_AXI_HP0]
if {[llength $hp0_pin] == 0} {
    puts "ERROR: Could not find PS high-performance slave interface S_AXI_HP0"
    exit 1
}

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_hp0_interconnect
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_hp0_interconnect]

connect_bd_intf_net $m_axi_pin [get_bd_intf_pins axi_hp0_interconnect/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_hp0_interconnect/M00_AXI] $hp0_pin

set fclk0_pin [get_bd_pins -quiet processing_system7_0/FCLK_CLK0]
if {[llength $fclk0_pin] == 0} {
    puts "ERROR: Could not find processing_system7_0/FCLK_CLK0"
    exit 1
}

foreach clk_pin_name {ACLK S00_ACLK M00_ACLK} {
    set clk_pin [get_bd_pins -quiet axi_hp0_interconnect/$clk_pin_name]
    if {[llength $clk_pin] != 0} {
        connect_bd_net $fclk0_pin $clk_pin
    }
}

set hp0_aclk_pin [get_bd_pins -quiet processing_system7_0/S_AXI_HP0_ACLK]
if {[llength $hp0_aclk_pin] != 0} {
    connect_bd_net $fclk0_pin $hp0_aclk_pin
}

set resetn_pin [get_bd_pins -quiet -hier -filter {NAME == peripheral_aresetn && DIR == O}]
if {[llength $resetn_pin] == 0} {
    puts "ERROR: Could not find processor system reset peripheral_aresetn"
    exit 1
}
set resetn_pin [lindex $resetn_pin 0]

foreach rst_pin_name {ARESETN S00_ARESETN M00_ARESETN} {
    set rst_pin [get_bd_pins -quiet axi_hp0_interconnect/$rst_pin_name]
    if {[llength $rst_pin] != 0} {
        connect_bd_net $resetn_pin $rst_pin
    }
}

assign_bd_address
validate_bd_design
save_bd_design

set bd_file [get_files "$build_dir/$project_name.srcs/sources_1/bd/$design_name/$design_name.bd"]
generate_target all $bd_file

set wrapper_file [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper_file
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set bit_file [file join $build_dir "$project_name.runs" impl_1 "${design_name}_wrapper.bit"]
set hwh_file [file join $build_dir "$project_name.srcs" sources_1 bd $design_name hw_handoff "${design_name}.hwh"]

if {[file exists $bit_file]} {
    file copy -force $bit_file [file join $pynq_dir base_add.bit]
    puts "Copied bitstream to [file join $pynq_dir base_add.bit]"
} else {
    puts "WARNING: Bitstream not found: $bit_file"
}

if {[file exists $hwh_file]} {
    file copy -force $hwh_file [file join $pynq_dir base_add.hwh]
    puts "Copied handoff to [file join $pynq_dir base_add.hwh]"
} else {
    puts "WARNING: HWH not found: $hwh_file"
}

exit

