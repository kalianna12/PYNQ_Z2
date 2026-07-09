set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set project_name base_add_overlay
set design_name system
set part_name xc7z020clg400-1
set board_part www.digilentinc.com:pynq-z1:part0:1.0

set build_dir [file join $root_dir build vivado]
set pynq_dir [file join $root_dir pynq]
set board_repo_dir [file join $root_dir board_files]
set external_board_repo_dir [file normalize "G:/FIREFOX下载"]
set rtl_src [list \
    [file join $root_dir rtl src led_ctrl_axi.v] \
    [file join $root_dir rtl src ad9102_ctrl_axi.v] \
    [file join $root_dir rtl src adc_ctrl_axi.v] \
    [file join $root_dir rtl src ad9226_capture_core.v] \
    [file join $root_dir rtl src adc_sample_fifo.v] \
    [file join $root_dir rtl src adc_capture_system.v] \
]
set board_io_xdc [file join $root_dir constraints lemon_pynqz1_board_io.xdc]
set adc_xdc [file join $root_dir constraints lemon_pynqz1_adc_system.xdc]
set ad9102_xdc [file join $root_dir constraints lemon_pynqz1_ad9102.xdc]

file mkdir $build_dir
file mkdir $pynq_dir

set board_repo_paths [list]
if {[file exists $external_board_repo_dir]} {
    lappend board_repo_paths $external_board_repo_dir
}
if {[file exists $board_repo_dir]} {
    lappend board_repo_paths $board_repo_dir
}
if {[llength $board_repo_paths] != 0} {
    set_param board.repoPaths $board_repo_paths
}

create_project -force $project_name $build_dir -part $part_name
set_property board_part $board_part [current_project]
add_files -norecurse $rtl_src
add_files -fileset constrs_1 -norecurse $board_io_xdc
if {[file exists $adc_xdc]} {
    add_files -fileset constrs_1 -norecurse $adc_xdc
    set_property PROCESSING_ORDER LATE [get_files $adc_xdc]
} else {
    puts "WARNING: ADC XDC not found: $adc_xdc"
}
if {[file exists $ad9102_xdc]} {
    add_files -fileset constrs_1 -norecurse $ad9102_xdc
} else {
    puts "WARNING: AD9102 XDC not found: $ad9102_xdc"
}
update_ip_catalog

create_bd_design $design_name

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
set_property -dict [list \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {125.000000} \
] [get_bd_cells processing_system7_0]

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR"} \
    [get_bd_cells processing_system7_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 adc_clock_wizard_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {125.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {62.500} \
    CONFIG.CLKOUT1_REQUESTED_PHASE {0.000} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {62.500} \
    CONFIG.CLKOUT2_REQUESTED_PHASE {258.750} \
    CONFIG.USE_RESET {false} \
] [get_bd_cells adc_clock_wizard_0]

create_bd_cell -type module -reference led_ctrl_axi led_ctrl_0

set led_ctrl_pin [get_bd_intf_pins -quiet led_ctrl_0/S_AXI]
if {[llength $led_ctrl_pin] == 0} {
    puts "ERROR: Could not find AXI-Lite interface S_AXI on led_ctrl_0"
    exit 1
}

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto"} \
    $led_ctrl_pin

make_bd_pins_external [get_bd_pins led_ctrl_0/leds_4bits_tri_o]
make_bd_pins_external [get_bd_pins led_ctrl_0/rgb_leds_6bits_tri_o]
make_bd_pins_external [get_bd_pins led_ctrl_0/btns_4bits_tri_i]
set led_bd_port [get_bd_ports -quiet leds_4bits_tri_o_0]
if {[llength $led_bd_port] != 0} {
    set_property name leds_4bits_tri_o $led_bd_port
}
foreach ext_pair {
    {rgb_leds_6bits_tri_o_0 rgb_leds_6bits_tri_o}
    {btns_4bits_tri_i_0 btns_4bits_tri_i}
} {
    set old_name [lindex $ext_pair 0]
    set new_name [lindex $ext_pair 1]
    set bd_port [get_bd_ports -quiet $old_name]
    if {[llength $bd_port] != 0} {
        set_property name $new_name $bd_port
    }
}

create_bd_cell -type module -reference adc_capture_system adc_capture_0

set adc_ctrl_pin [get_bd_intf_pins -quiet adc_capture_0/S_AXI]
if {[llength $adc_ctrl_pin] == 0} {
    puts "ERROR: Could not find AXI-Lite interface S_AXI on adc_capture_0"
    exit 1
}

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto"} \
    $adc_ctrl_pin

foreach adc_pin_name {adc_a_clk adc_b_clk adc_a_ora adc_b_orb adc_a_data adc_b_data} {
    set adc_pin [get_bd_pins -quiet adc_capture_0/$adc_pin_name]
    if {[llength $adc_pin] != 0} {
        make_bd_pins_external $adc_pin
    }
}

foreach ext_pair {
    {adc_a_clk_0 adc_a_clk}
    {adc_b_clk_0 adc_b_clk}
    {adc_a_ora_0 adc_a_ora}
    {adc_b_orb_0 adc_b_orb}
    {adc_a_data_0 adc_a_data}
    {adc_b_data_0 adc_b_data}
} {
    set old_name [lindex $ext_pair 0]
    set new_name [lindex $ext_pair 1]
    set bd_port [get_bd_ports -quiet $old_name]
    if {[llength $bd_port] != 0} {
        set_property name $new_name $bd_port
    }
}

create_bd_cell -type module -reference ad9102_ctrl_axi ad9102_ctrl_0

set ad9102_ctrl_pin [get_bd_intf_pins -quiet ad9102_ctrl_0/S_AXI]
if {[llength $ad9102_ctrl_pin] == 0} {
    puts "ERROR: Could not find AXI-Lite interface S_AXI on ad9102_ctrl_0"
    exit 1
}

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto"} \
    $ad9102_ctrl_pin

foreach ad9102_pin_name {
    ad9102_cs_n
    ad9102_sdo
    ad9102_sdio
    ad9102_sclk
    ad9102_clk_cmos_in
    ad9102_trigger_n
    ad9102_reset_n
} {
    set ad9102_pin [get_bd_pins -quiet ad9102_ctrl_0/$ad9102_pin_name]
    if {[llength $ad9102_pin] != 0} {
        make_bd_pins_external $ad9102_pin
    }
}

foreach ad9102_pin_name {
    ad9102_cs_n
    ad9102_sdo
    ad9102_sdio
    ad9102_sclk
    ad9102_clk_cmos_in
    ad9102_trigger_n
    ad9102_reset_n
} {
    set generated_port [get_bd_ports -quiet "${ad9102_pin_name}_0"]
    if {[llength $generated_port] != 0} {
        set_property name $ad9102_pin_name $generated_port
    }
}

set adc_axis_pin [get_bd_intf_pins -quiet adc_capture_0/M_AXIS_SAMPLE]
if {[llength $adc_axis_pin] == 0} {
    puts "ERROR: Could not find AXI-Stream output interface M_AXIS_SAMPLE on adc_capture_0"
    exit 1
}

set axis_fifo_vlnv xilinx.com:ip:axis_data_fifo:2.0
if {[llength [get_ipdefs -all $axis_fifo_vlnv]] == 0} {
    puts "ERROR: Could not find supported AXIS Data FIFO IP: $axis_fifo_vlnv"
    exit 1
}
create_bd_cell -type ip -vlnv $axis_fifo_vlnv axis_data_fifo_0
set_property -dict [list \
    CONFIG.TDATA_NUM_BYTES {4} \
    CONFIG.FIFO_DEPTH {16384} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.HAS_TKEEP {1} \
] [get_bd_cells axis_data_fifo_0]

set dma_vlnv xilinx.com:ip:axi_dma:7.1
if {[llength [get_ipdefs -all $dma_vlnv]] == 0} {
    puts "ERROR: Could not find supported AXI DMA IP: $dma_vlnv"
    exit 1
}
create_bd_cell -type ip -vlnv $dma_vlnv axi_dma_0
set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_sg_length_width {21} \
    CONFIG.c_m_axi_s2mm_data_width {64} \
    CONFIG.c_s2mm_burst_size {16} \
] [get_bd_cells axi_dma_0]

connect_bd_intf_net $adc_axis_pin [get_bd_intf_pins axis_data_fifo_0/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins axis_data_fifo_0/M_AXIS] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

set dma_lite_pin [get_bd_intf_pins -quiet axi_dma_0/S_AXI_LITE]
if {[llength $dma_lite_pin] == 0} {
    puts "ERROR: Could not find AXI DMA S_AXI_LITE"
    exit 1
}

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto"} \
    $dma_lite_pin

set dma_s2mm_pin [get_bd_intf_pins -quiet axi_dma_0/M_AXI_S2MM]
if {[llength $dma_s2mm_pin] == 0} {
    puts "ERROR: Could not find AXI DMA M_AXI_S2MM"
    exit 1
}

set hp0_pin [get_bd_intf_pins -quiet processing_system7_0/S_AXI_HP0]
if {[llength $hp0_pin] == 0} {
    puts "ERROR: Could not find PS high-performance slave interface S_AXI_HP0"
    exit 1
}

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_hp0_interconnect
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_hp0_interconnect]

connect_bd_intf_net $dma_s2mm_pin [get_bd_intf_pins axi_hp0_interconnect/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_hp0_interconnect/M00_AXI] $hp0_pin

set fclk0_pin [get_bd_pins -quiet processing_system7_0/FCLK_CLK0]
if {[llength $fclk0_pin] == 0} {
    puts "ERROR: Could not find processing_system7_0/FCLK_CLK0"
    exit 1
}

connect_bd_net $fclk0_pin [get_bd_pins adc_clock_wizard_0/clk_in1]
connect_bd_net \
    [get_bd_pins adc_clock_wizard_0/clk_out1] \
    [get_bd_pins adc_capture_0/adc_clk_62m5]
connect_bd_net \
    [get_bd_pins adc_clock_wizard_0/clk_out2] \
    [get_bd_pins adc_capture_0/adc_capture_clk_62m5]
connect_bd_net \
    [get_bd_pins adc_clock_wizard_0/locked] \
    [get_bd_pins adc_capture_0/adc_clock_locked]

foreach clk_target {
    led_ctrl_0/S_AXI_ACLK
    ad9102_ctrl_0/S_AXI_ACLK
    adc_capture_0/S_AXI_ACLK
    axi_dma_0/s_axi_lite_aclk
    axi_dma_0/m_axi_s2mm_aclk
    axis_data_fifo_0/s_axis_aclk
    axis_data_fifo_0/m_axis_aclk
    axis_data_fifo_0/aclk
} {
    set clk_pin [get_bd_pins -quiet $clk_target]
    if {[llength $clk_pin] != 0 && [llength [get_bd_nets -quiet -of_objects $clk_pin]] == 0} {
        connect_bd_net $fclk0_pin $clk_pin
    }
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

foreach rst_target {
    led_ctrl_0/S_AXI_ARESETN
    ad9102_ctrl_0/S_AXI_ARESETN
    adc_capture_0/S_AXI_ARESETN
    axi_dma_0/axi_resetn
    axis_data_fifo_0/s_axis_aresetn
    axis_data_fifo_0/m_axis_aresetn
    axis_data_fifo_0/aresetn
} {
    set rst_pin [get_bd_pins -quiet $rst_target]
    if {[llength $rst_pin] != 0 && [llength [get_bd_nets -quiet -of_objects $rst_pin]] == 0} {
        connect_bd_net $resetn_pin $rst_pin
    }
}

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
set_property top ${design_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]

launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set bit_file [file join $build_dir "$project_name.runs" impl_1 "${design_name}_wrapper.bit"]
set hwh_file [file join $build_dir "$project_name.srcs" sources_1 bd $design_name hw_handoff "${design_name}.hwh"]
set hwh_file_gen [file join $build_dir "$project_name.gen" sources_1 bd $design_name hw_handoff "${design_name}.hwh"]

if {[file exists $bit_file]} {
    file copy -force $bit_file [file join $pynq_dir base_add.bit]
    puts "Copied bitstream to [file join $pynq_dir base_add.bit]"
} else {
    puts "WARNING: Bitstream not found: $bit_file"
}

if {[file exists $hwh_file]} {
    file copy -force $hwh_file [file join $pynq_dir base_add.hwh]
    puts "Copied handoff to [file join $pynq_dir base_add.hwh]"
} elseif {[file exists $hwh_file_gen]} {
    file copy -force $hwh_file_gen [file join $pynq_dir base_add.hwh]
    puts "Copied handoff to [file join $pynq_dir base_add.hwh]"
} else {
    puts "WARNING: HWH not found: $hwh_file or $hwh_file_gen"
}

exit
