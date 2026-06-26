set script_dir [file dirname [file normalize [info script]]]
cd $script_dir

# Avoid inheriting a Windows DEBUG=release variable into Vivado HLS makefiles.
set ::env(DEBUG) ""

open_project -reset base_add_prj
set_top base_add

add_files src/base_add.cpp
add_files src/base_add.h
add_files -tb tb/test_base_add.cpp

open_solution -reset "solution1"
set_part {xc7z020clg400-1}
create_clock -period 10 -name default

csim_design
csynth_design

set export_rc [catch {export_design -format ip_catalog} export_msg]
if {$export_rc} {
    puts "WARNING: export_design failed: $export_msg"
    puts "Applying Vivado 2018.2 core_revision workaround for modern dates."

    set ip_dir [file normalize [file join [pwd] base_add_prj solution1 impl ip]]
    set ippack_tcl [file join $ip_dir run_ippack.tcl]

    if {![file exists $ippack_tcl]} {
        puts "ERROR: Could not find $ippack_tcl"
        exit 1
    }

    set f [open $ippack_tcl r]
    set data [read $f]
    close $f

    regsub {set Revision[ \t]+"[0-9]+"} $data {set Revision    "1"} data

    set f [open $ippack_tcl w]
    puts -nonewline $f $data
    close $f

    cd $ip_dir
    exec G:/Xilinx/Vivado/2018.2/bin/vivado.bat -mode batch -source run_ippack.tcl
}

exit

