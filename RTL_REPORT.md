# RTL Report

Generated: **2026-05-24 17:28:09**

## 1. RTL Simulation Status

| Item | Status | What It Means |
|---|---|---|
| RTL behavioral simulation | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | Verilog testbench result before Vivado overlay integration |

Key result:

~~~text
FINAL: PASS led_ctrl_axi direct/blink/walk/counter modes
~~~

## 2. RTL Source Files

| File | Status | Last Write Time |
|---|---|---|
| led_ctrl_axi.v | <span style="color:#008000;font-weight:bold;">FOUND</span> | 2026-05-24 16:59:06 |

## 3. RTL Testbench Files

| File | Status | Last Write Time |
|---|---|---|
| tb_led_ctrl_axi.v | <span style="color:#008000;font-weight:bold;">FOUND</span> | 2026-05-24 17:03:36 |

## 4. Simulated Register Map

These are RTL module offsets. The base address must still come from generated
Vivado .hwh or Vivado logs.

~~~text
0x00 CTRL        bit0 enable, bits[3:1] mode
0x04 SPEED_DIV   blink/walk/counter divider
0x08 LED_VALUE   manual LED value, bits[3:0]
0x0C STATUS      bits[3:0] current LED, bits[7:4] tick counter
~~~

## 5. Board Constraints Used By RTL

Source file:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\constraints\pynqz2_leds.xdc
~~~

Key pin constraints:

~~~text
set_property PACKAGE_PIN R14 $led0
set_property PACKAGE_PIN P14 $led1
set_property PACKAGE_PIN N16 $led2
set_property PACKAGE_PIN M14 $led3
set_property IOSTANDARD LVCMOS33 $led0
set_property IOSTANDARD LVCMOS33 $led1
set_property IOSTANDARD LVCMOS33 $led2
set_property IOSTANDARD LVCMOS33 $led3
~~~

## 6. Logs

Main Vivado simulation log:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\rtl\sim\led_ctrl_axi_sim.log
~~~

Inner xsim log:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\rtl\sim\led_ctrl_axi_sim.sim\sim_1\behav\xsim\simulate.log
~~~

## 7. Next Step

If this report shows **PASS**, run:

~~~text
FPGA: 2 Build Vivado Overlay
~~~

