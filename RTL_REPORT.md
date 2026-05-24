# RTL Report

Generated: **2026-05-24 20:09:39**

## 1. RTL Simulation Status

| Item | Status | What It Means |
|---|---|---|
| LED AXI-Lite simulation | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | Existing PS-controlled LED RTL testbench |
| AD9226 capture simulation | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | New capture_core + FIFO fake/real stream testbench |
| Overall RTL simulation | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | All RTL testbenches before Vivado overlay integration |

Key result:

~~~text
FINAL: PASS led_ctrl_axi direct/blink/walk/counter modes
FINAL: PASS ad9226 capture fake/real/fifo overflow/decimation/pre_delay config rules
~~~

## 2. RTL Source Files

| File | Status | Last Write Time |
|---|---|---|
| ad9226_capture_core.v | <span style="color:#008000;font-weight:bold;">FOUND</span> | 2026-05-24 19:44:06 |
| adc_capture_system.v | <span style="color:#008000;font-weight:bold;">FOUND</span> | 2026-05-24 19:44:35 |
| adc_ctrl_axi.v | <span style="color:#008000;font-weight:bold;">FOUND</span> | 2026-05-24 18:48:04 |
| adc_sample_fifo.v | <span style="color:#008000;font-weight:bold;">FOUND</span> | 2026-05-24 19:43:12 |
| led_ctrl_axi.v | <span style="color:#008000;font-weight:bold;">FOUND</span> | 2026-05-24 16:59:06 |

## 3. RTL Testbench Files

| File | Status | Last Write Time |
|---|---|---|
| tb_ad9226_capture_chain.v | <span style="color:#008000;font-weight:bold;">FOUND</span> | 2026-05-24 19:57:12 |
| tb_led_ctrl_axi.v | <span style="color:#008000;font-weight:bold;">FOUND</span> | 2026-05-24 17:03:36 |

## 4. Simulated Register Map

These are RTL module offsets. The base address must still come from generated
Vivado .hwh or Vivado logs. In PYNQ, ip.write(offset, value) uses the
IP-local offset, not ase_address + offset.

~~~text
led_ctrl_axi:
0x00 CTRL        bit0 enable, bits[3:1] mode
0x04 SPEED_DIV   blink/walk/counter divider
0x08 LED_VALUE   manual LED value, bits[3:0]
0x0C STATUS      bits[3:0] current LED, bits[7:4] tick counter

adc_ctrl_axi planned:
0x00 CTRL         bit0 enable, bit1 start pulse, bit2 clear pulse, bit6 soft_reset
0x04 STATUS       busy/done/adc_clk_seen/fifo/error/data_changed
0x08 SAMPLE_COUNT saved sample count
0x0C ADC_HALF     ADC clock half period
0x10 SAMPLE_DELAY delay in clk_125m cycles
0x14 DECIMATION   save 1 per N ADC samples
0x18 CHANNEL_MASK bit0 A, bit1 B
0x1C CAPTURE_MODE 0 writer fake, 1 real ADC, 2 capture_core fake stream
0x48 SAVED_COUNTER
0x4C LAST_SAMPLE_WORD
0x50 DEBUG_STATE
~~~

## 5. Board Constraints Used By RTL

Source file:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\constraints\pynqz2_leds.xdc
~~~

Key pin constraints:

~~~text
set_property PACKAGE_PIN R14 [get_ports {leds_4bits_tri_o[0]}]
set_property PACKAGE_PIN P14 [get_ports {leds_4bits_tri_o[1]}]
set_property PACKAGE_PIN N16 [get_ports {leds_4bits_tri_o[2]}]
set_property PACKAGE_PIN M14 [get_ports {leds_4bits_tri_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_4bits_tri_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_4bits_tri_o[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_4bits_tri_o[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_4bits_tri_o[3]}]
~~~

## 6. Logs

LED Vivado simulation log:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\rtl\sim\led_ctrl_axi_sim.log
~~~

LED inner xsim log:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\rtl\sim\led_ctrl_axi_sim.sim\sim_1\behav\xsim\simulate.log
~~~

AD9226 capture Vivado simulation log:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\rtl\sim\ad9226_capture_sim.log
~~~

AD9226 capture inner xsim log:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\rtl\sim\ad9226_capture_sim.sim\sim_1\behav\xsim\simulate.log
~~~

## 7. Next Step

If this report shows **PASS**, run:

~~~text
FPGA: 2 Build Vivado Overlay
~~~

