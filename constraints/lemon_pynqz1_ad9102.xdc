## AD9102 SPI/control interface on the left expansion header.
## Pin order supplied by the user:
##   CS, SDO, SDIO, SCLK -> U12, V13, T15, U17
##   CLK_CMOS_IN, TRIGGER, RST -> U13, T14, T16

set_property PACKAGE_PIN U12 [get_ports ad9102_cs_n]
set_property PACKAGE_PIN V13 [get_ports ad9102_sdo]
set_property PACKAGE_PIN T15 [get_ports ad9102_sdio]
set_property PACKAGE_PIN U17 [get_ports ad9102_sclk]
set_property PACKAGE_PIN U13 [get_ports ad9102_clk_cmos_in]
set_property PACKAGE_PIN T14 [get_ports ad9102_trigger_n]
set_property PACKAGE_PIN T16 [get_ports ad9102_reset_n]

set_property IOSTANDARD LVCMOS33 [get_ports {
    ad9102_cs_n
    ad9102_sdo
    ad9102_sdio
    ad9102_sclk
    ad9102_clk_cmos_in
    ad9102_trigger_n
    ad9102_reset_n
}]

set_property DRIVE 8 [get_ports {
    ad9102_cs_n
    ad9102_sdio
    ad9102_sclk
    ad9102_trigger_n
    ad9102_reset_n
}]
set_property SLEW SLOW [get_ports {
    ad9102_cs_n
    ad9102_sdio
    ad9102_sclk
    ad9102_trigger_n
    ad9102_reset_n
}]
