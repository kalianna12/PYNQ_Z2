set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set work_dir [file join $root_dir rtl sim ad9102_direct]
set vivado_bin [file join $::env(XILINX_VIVADO) bin]

file mkdir $work_dir
cd $work_dir

set rtl_file [file join $root_dir rtl src ad9102_ctrl_axi.v]
set tb_file [file join $root_dir rtl tb tb_ad9102_ctrl_axi.v]

puts [exec cmd.exe /d /c call [file join $vivado_bin xvlog.bat] \
    --relax $rtl_file $tb_file 2>@1]
puts [exec cmd.exe /d /c call [file join $vivado_bin xelab.bat] \
    --relax --debug typical tb_ad9102_ctrl_axi -s ad9102_ctrl_sim 2>@1]
puts [exec cmd.exe /d /c call [file join $vivado_bin xsim.bat] \
    ad9102_ctrl_sim -runall 2>@1]

exit
