# Vivado Overlay Report

Generated: **2026-06-28 22:45:43**

## 1. Build Status

| Item | Status | What It Means |
|---|---|---|
| Bitstream generation | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | .bit was created |
| Copy bit to pynq folder | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | pynq/base_add.bit updated |
| Copy hwh to pynq folder | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | pynq/base_add.hwh updated |
| RTL LED controller in HWH | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | PS can discover the AXI-Lite LED IP from .hwh |
| 4 single-color LED output port | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | leds_4bits_tri_o is exported to board pins |
| 2 RGB LED output port | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | rgb_leds_6bits_tri_o is exported to board pins |
| 4 button input port | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | btns_4bits_tri_i is exported to board pins |
| AD9226 capture controller in HWH | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | PS can discover adc_capture_0 from hwh |
| AD9102 SPI controller in HWH | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | PS can discover ad9102_ctrl_0 from hwh |
| AXI DMA S2MM in HWH | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | PS can discover axi_dma_0 and use recvchannel |
| AXI DMA in BD script | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | build.tcl creates axi_dma_0 and connects S2MM stream |
| AXIS Data FIFO in HWH | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | Xilinx FIFO buffers capture stream before DMA |
| AXIS Data FIFO in BD script | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | build.tcl creates axis_data_fifo_0 between capture and DMA |
| adc_capture_0 to AXIS FIFO | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | M_AXIS_SAMPLE is wired into axis_data_fifo_0/S_AXIS |
| AXIS FIFO to DMA S2MM | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | axis_data_fifo_0/M_AXIS is wired into axi_dma_0/S_AXIS_S2MM |
| DMA S2MM to PS HP0 | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | axi_dma_0/M_AXI_S2MM reaches PS DDR through S_AXI_HP0 |
| DMA S_AXI_LITE to PS GP0 | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | PS can configure DMA registers through M_AXI_GP0 |
| DMA S2MM interrupt | <span style="color:#64748b;font-weight:bold;">OPTIONAL</span> | Optional; current PYNQ flow can use polling/wait |
| AXI DMA mode | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | SG=0, MM2S=0, S2MM=1 |
| AXIS Data FIFO depth | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | FIFO_DEPTH=16384 words; target value is 16384 |
| AXI DMA data widths | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | M_AXI_S2MM=64 bits, S_AXIS_S2MM=32 bits; target is 64/32 |
| AXI DMA Buffer Length Register Width | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | c_sg_length_width = 21; must cover 262144 uint32 samples |
| Max DMA transfer bytes | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | Max BTT = 2097151 bytes; 262144 samples need 1048576 bytes |
| FCLK_CLK0 in HWH | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | HWH declares FCLK_CLK0 as 125000000 Hz; target is 125000000 Hz and Python PL_CLK_HZ must match. |
| Routed timing | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | Final implemented timing result |

## 2. PS Address Map For PYNQ

These addresses come from pynq/base_add.hwh. Notebook code should use these
fixed MMIO addresses directly instead of guessing through overlay attributes.

| Instance | Base | High | Range | Slave Interface | PYNQ Access |
|---|---:|---:|---:|---|---|
| led_ctrl_0 | 0x40000000 | 0x40000FFF | 0x1000 | S_AXI | MMIO(0x40000000, 0x1000) |
| adc_capture_0 | 0x40001000 | 0x40001FFF | 0x1000 | S_AXI | MMIO(0x40001000, 0x1000) |
| ad9102_ctrl_0 | 0x40002000 | 0x40002FFF | 0x1000 | S_AXI | MMIO(0x40002000, 0x1000) |
| axi_dma_0 | 0x40400000 | 0x4040FFFF | 0x10000 | S_AXI_LITE | overlay.axi_dma_0 / DMA MMIO 0x40400000 |

Recommended direct bindings:

~~~text
led_ip = MMIO(0x40000000, 0x1000)
adc_ip = MMIO(0x40001000, 0x1000)
dds_ip = MMIO(0x40002000, 0x1000)
dma = overlay.axi_dma_0
~~~

## 3. Register Offsets Used By Notebook

LED/RGB/button controller at `0x40000000`:

| Register | Offset | Meaning |
|---|---:|---|
| LED_CTRL | 0x00 | write 0x00 for manual board IO mode |
| LED_VALUE | 0x08 | bits[3:0]=LD0..LD3, bits[6:4]=LD5 RGB, bits[9:7]=LD4 RGB |
| LED_STATUS | 0x0C | bits[3:0]=LED value, bits[9:4]=RGB value, bits[13:10]=BTN0..BTN3 |

ADC capture controller at `0x40001000`:

| Register | Offset | Meaning |
|---|---:|---|
| CTRL | 0x00 | bit0 enable, bit1 start pulse, bit2 clear/reset pulse |
| STATUS | 0x04 | busy/done/fatal status |
| SAMPLE_COUNT | 0x08 | number of 32-bit sample words sent to DMA |
| ADC_HALF | 0x0C | ADC clock half-period in 125 MHz FCLK cycles |
| SAMPLE_DELAY | 0x10 | ADC data sample delay in FCLK cycles |
| DECIMATION | 0x14 | save one sample per N ADC cycles |
| CHANNEL_MASK | 0x18 | bit0 channel A, bit1 channel B |
| CAPTURE_MODE | 0x1C | 1 real ADC, 2 fake stream |
| TRIGGER_MODE | 0x20 | current generic tests use 0 |
| PRE_DELAY | 0x24 | current generic tests use 0 |
| BUFFER_SELECT | 0x28 | current generic tests use 0 |
| LATEST_A | 0x2C | latest raw channel A sample |
| LATEST_B | 0x30 | latest raw channel B sample |
| SAMPLE_COUNTER | 0x34 | ADC sample counter |
| FIFO_LEVEL | 0x38 | internal FIFO level |
| ERROR_FLAGS | 0x3C | write all ones to clear warning/error flags |
| VERSION | 0x44 | RTL version/debug value |
| SAVED_COUNTER | 0x48 | saved sample counter |
| LAST_AXIS_WORD | 0x4C | last packed AXIS word |
| DEBUG_STATE | 0x50 | capture FSM debug state |
| AXIS_SENT_COUNT | 0x54 | number of AXIS words sent |
| AXIS_STALL_COUNT | 0x58 | AXIS stall counter |
| TLAST_COUNT | 0x5C | expected 1 per capture |
| FIFO_BACKPRESSURE | 0x60 | FIFO backpressure counter |
| DROPPED_SAMPLE_COUNT | 0x64 | expected 0 |
| CAPTURE_DONE_LATCHED | 0x68 | latched done flag |
| CORE_DONE | 0x6C | capture core done flag |

AD9102 controller at `0x40002000`:

| Register | Offset | Meaning |
|---|---:|---|
| CTRL | 0x00 | bit0 start SPI transaction, bit1 read, bit2 clear done |
| STATUS | 0x04 | busy, done, read, trigger/reset and clock-pin sample |
| SPI_ADDR | 0x08 | AD9102 15-bit SPI register/SRAM address |
| SPI_WDATA | 0x0C | 16-bit write payload |
| SPI_RDATA | 0x10 | 16-bit read payload |
| SPI_DIV | 0x14 | SCLK half-period minus one in 125 MHz FCLK cycles |
| GPIO_CTRL | 0x18 | bit0 TRIGGER_N, bit1 RESET_N |
| DAC_CLK_HZ | 0x1C | fixed readback 180000000 |
| VERSION | 0x20 | expected 0xAD910201 |
| COMMAND_COUNT | 0x24 | completed/started SPI command debug counter |
| ERROR_COUNT | 0x28 | command-while-busy error counter |

AXI DMA at `0x40400000`:

| Register | Offset | Meaning |
|---|---:|---|
| S2MM_DMASR | 0x34 | DMA S2MM status register used by debug code |

## 4. Exposed PL Pin Map

These rows come from the active Lemon/PYNQ-Z1 XDC files. They are the board pins
the bitstream exposes.

| HDL Top Port | Board Meaning | PACKAGE_PIN | XDC File |
|---|---|---|---|
| leds_4bits_tri_o[0] | LD0 | R14 | lemon_pynqz1_board_io.xdc |
| leds_4bits_tri_o[1] | LD1 | P14 | lemon_pynqz1_board_io.xdc |
| leds_4bits_tri_o[2] | LD2 | N16 | lemon_pynqz1_board_io.xdc |
| leds_4bits_tri_o[3] | LD3 | M14 | lemon_pynqz1_board_io.xdc |
| rgb_leds_6bits_tri_o[0] | LD5_R | M15 | lemon_pynqz1_board_io.xdc |
| rgb_leds_6bits_tri_o[1] | LD5_G | L14 | lemon_pynqz1_board_io.xdc |
| rgb_leds_6bits_tri_o[2] | LD5_B | G14 | lemon_pynqz1_board_io.xdc |
| rgb_leds_6bits_tri_o[3] | LD4_R | N15 | lemon_pynqz1_board_io.xdc |
| rgb_leds_6bits_tri_o[4] | LD4_G | G17 | lemon_pynqz1_board_io.xdc |
| rgb_leds_6bits_tri_o[5] | LD4_B | L15 | lemon_pynqz1_board_io.xdc |
| btns_4bits_tri_i[0] | BTN0 | D19 | lemon_pynqz1_board_io.xdc |
| btns_4bits_tri_i[1] | BTN1 | D20 | lemon_pynqz1_board_io.xdc |
| btns_4bits_tri_i[2] | BTN2 | L20 | lemon_pynqz1_board_io.xdc |
| btns_4bits_tri_i[3] | BTN3 | L19 | lemon_pynqz1_board_io.xdc |
| adc_a_clk | AD9226 A clock | T9 | lemon_pynqz1_adc_system.xdc |
| adc_a_data[0] | AD9226 A D0 | U10 | lemon_pynqz1_adc_system.xdc |
| adc_a_data[1] | AD9226 A D1 | V6 | lemon_pynqz1_adc_system.xdc |
| adc_a_data[2] | AD9226 A D2 | W6 | lemon_pynqz1_adc_system.xdc |
| adc_a_data[3] | AD9226 A D3 | Y9 | lemon_pynqz1_adc_system.xdc |
| adc_a_data[4] | AD9226 A D4 | Y8 | lemon_pynqz1_adc_system.xdc |
| adc_a_data[5] | AD9226 A D5 | Y7 | lemon_pynqz1_adc_system.xdc |
| adc_a_data[6] | AD9226 A D6 | Y6 | lemon_pynqz1_adc_system.xdc |
| adc_a_data[7] | AD9226 A D7 | T5 | lemon_pynqz1_adc_system.xdc |
| adc_a_data[8] | AD9226 A D8 | U5 | lemon_pynqz1_adc_system.xdc |
| adc_a_data[9] | AD9226 A D9 | U7 | lemon_pynqz1_adc_system.xdc |
| adc_a_data[10] | AD9226 A D10 | V7 | lemon_pynqz1_adc_system.xdc |
| adc_a_data[11] | AD9226 A D11 | V8 | lemon_pynqz1_adc_system.xdc |
| adc_a_ora | AD9226 A ORA | W8 | lemon_pynqz1_adc_system.xdc |
| adc_b_clk | AD9226 B clock | V11 | lemon_pynqz1_adc_system.xdc |
| adc_b_data[0] | AD9226 B D0 | V10 | lemon_pynqz1_adc_system.xdc |
| adc_b_data[1] | AD9226 B D1 | Y12 | lemon_pynqz1_adc_system.xdc |
| adc_b_data[2] | AD9226 B D2 | Y13 | lemon_pynqz1_adc_system.xdc |
| adc_b_data[3] | AD9226 B D3 | W11 | lemon_pynqz1_adc_system.xdc |
| adc_b_data[4] | AD9226 B D4 | Y11 | lemon_pynqz1_adc_system.xdc |
| adc_b_data[5] | AD9226 B D5 | V5 | lemon_pynqz1_adc_system.xdc |
| adc_b_data[6] | AD9226 B D6 | J15 | lemon_pynqz1_adc_system.xdc |
| adc_b_data[7] | AD9226 B D7 | H15 | lemon_pynqz1_adc_system.xdc |
| adc_b_data[8] | AD9226 B D8 | F16 | lemon_pynqz1_adc_system.xdc |
| adc_b_data[9] | AD9226 B D9 | F19 | lemon_pynqz1_adc_system.xdc |
| adc_b_data[10] | AD9226 B D10 | F20 | lemon_pynqz1_adc_system.xdc |
| adc_b_data[11] | AD9226 B D11 | B19 | lemon_pynqz1_adc_system.xdc |
| adc_b_orb | AD9226 B ORB | A20 | lemon_pynqz1_adc_system.xdc |
| ad9102_cs_n | AD9102 CS_N | U12 | lemon_pynqz1_ad9102.xdc |
| ad9102_sdo | AD9102 SDO | V13 | lemon_pynqz1_ad9102.xdc |
| ad9102_sdio | AD9102 SDIO | T15 | lemon_pynqz1_ad9102.xdc |
| ad9102_sclk | AD9102 SCLK | U17 | lemon_pynqz1_ad9102.xdc |
| ad9102_clk_cmos_in | AD9102 180 MHz clock monitor | U13 | lemon_pynqz1_ad9102.xdc |
| ad9102_trigger_n | AD9102 TRIGGER_N | T14 | lemon_pynqz1_ad9102.xdc |
| ad9102_reset_n | AD9102 RESET_N | T16 | lemon_pynqz1_ad9102.xdc |

## 5. Recommended DMA Files For PYNQ

These are the files to copy when validating the current DMA capture path.

| File | Status | Bytes | Last Write Time |
|---|---|---:|---|
| base_add.bit | <span style="color:#008000;font-weight:bold;">FOUND</span> | 4045674 | 2026-06-28 22:43:47 |
| base_add.hwh | <span style="color:#008000;font-weight:bold;">FOUND</span> | 357140 | 2026-06-28 22:38:51 |
| lemon_pynqz1_capture.py | <span style="color:#008000;font-weight:bold;">FOUND</span> | 6721 | 2026-06-27 03:41:42 |
| lemon_pynqz1_ad9102.py | <span style="color:#008000;font-weight:bold;">FOUND</span> | 10742 | 2026-06-28 22:45:32 |
| lemon_pynqz1_adc_dds_test.ipynb | <span style="color:#008000;font-weight:bold;">FOUND</span> | 4066 | 2026-06-28 22:45:22 |
| lemon_pynqz1_board_adc_test.ipynb | <span style="color:#008000;font-weight:bold;">FOUND</span> | 14289 | 2026-06-27 03:52:34 |

## 6. Board Files Present

| File | Status | Bytes | Last Write Time |
|---|---|---:|---|
| base_add.bit | <span style="color:#008000;font-weight:bold;">FOUND</span> | 4045674 | 2026-06-28 22:43:47 |
| base_add.hwh | <span style="color:#008000;font-weight:bold;">FOUND</span> | 357140 | 2026-06-28 22:38:51 |
| lemon_pynqz1_adc_dds_test.ipynb | <span style="color:#008000;font-weight:bold;">FOUND</span> | 4066 | 2026-06-28 22:45:22 |
| lemon_pynqz1_board_adc_test.ipynb | <span style="color:#008000;font-weight:bold;">FOUND</span> | 14289 | 2026-06-27 03:52:34 |
| lemon_pynqz1_ad9102.py | <span style="color:#008000;font-weight:bold;">FOUND</span> | 10742 | 2026-06-28 22:45:32 |
| lemon_pynqz1_capture.py | <span style="color:#008000;font-weight:bold;">FOUND</span> | 6721 | 2026-06-27 03:41:42 |

Legacy board notebooks have been moved to the history folder. Use the Lemon/PYNQ-Z1 notebook for board validation.

## 7. Timing Summary

Source file:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\build\vivado\base_add_overlay.runs\impl_1\system_wrapper_timing_summary_routed.rpt
~~~

| WNS ns | TNS ns | WHS ns | THS ns | Result |
|---:|---:|---:|---:|---|
| **0.797** | **0.000** | **0.028** | **0.000** | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> |

Good sign:

~~~text
All user specified timing constraints are met.
~~~

Rule: **WNS > 0** means setup timing passes.

## 8. Resource Report

Source file:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\build\vivado\base_add_overlay.runs\impl_1\system_wrapper_utilization_placed.rpt
~~~

Key lines:

~~~text
| Slice LUTs                 | 2601 |     0 |          0 |     53200 |  4.89 |
| Block RAM Tile    |   20 |     0 |          0 |       140 | 14.29 |
* Note: Each Block RAM Tile only has one FIFO logic available and therefore can accommodate only one FIFO36E1 or one FIFO18E1. However, if a FIFO18E1 occupies a Block RAM Tile, that tile can still accommodate a RAMB18E1
| DSPs      |    0 |     0 |          0 |       220 |  0.00 |
~~~

## 9. Vivado Project

| File | Status |
|---|---|
| build/vivado/base_add_overlay.xpr | <span style="color:#008000;font-weight:bold;">FOUND</span> |

Open this project only when you want to inspect the block design or timing in the GUI.

## 10. Next Step

If this report shows **PASS**, upload these files to PYNQ:

~~~text
pynq/base_add.bit
pynq/base_add.hwh
pynq/lemon_pynqz1_capture.py
pynq/lemon_pynqz1_ad9102.py
pynq/lemon_pynqz1_adc_dds_test.ipynb
pynq/lemon_pynqz1_board_adc_test.ipynb
~~~

For the Lemon/PYNQ-Z1 board validation path, use:

~~~text
pynq/lemon_pynqz1_board_adc_test.ipynb
~~~

Do not use old board notebooks when validating the Lemon/PYNQ-Z1 pinout.
Those belong to the previous board flow and can give misleading LED/button/ADC results.

