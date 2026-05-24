# Vivado Overlay Report

Generated: **2026-05-25 02:17:52**

## 1. Build Status

| Item | Status | What It Means |
|---|---|---|
| Bitstream generation | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | .bit was created |
| Copy bit to pynq folder | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | pynq/base_add.bit updated |
| Copy hwh to pynq folder | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | pynq/base_add.hwh updated |
| RTL LED controller in HWH | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | PS can discover the AXI-Lite LED IP from .hwh |
| AD9226 capture controller in HWH | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | PS can discover adc_capture_0 from hwh |
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
| AXI DMA data widths | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | M_AXI_S2MM=32 bits, S_AXIS_S2MM=32 bits |
| AXI DMA Buffer Length Register Width | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | c_sg_length_width = 23; required value is 23 |
| Max DMA transfer bytes | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | Max BTT = 8388607 bytes; 65536 samples need 262144 bytes |
| FCLK_CLK0 in HWH | <span style="color:#008000;font-weight:bold;">FOUND</span> | HWH declares FCLK_CLK0 as 50000000 Hz. PYNQ scripts may use measured PL_CLK_HZ; verify before interpreting sample-rate prints. |
| Routed timing | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | Final implemented timing result |

## 2. Recommended DMA Files For PYNQ

These are the files to copy when validating the current DMA capture path.

| File | Status | Bytes | Last Write Time |
|---|---|---:|---|
| base_add.bit | <span style="color:#008000;font-weight:bold;">FOUND</span> | 4045674 | 2026-05-25 02:16:28 |
| base_add.hwh | <span style="color:#008000;font-weight:bold;">FOUND</span> | 326156 | 2026-05-25 02:10:52 |
| ad9226_capture_smoke.py | <span style="color:#008000;font-weight:bold;">FOUND</span> | 6366 | 2026-05-25 01:46:49 |
| ad9226_capture_demo.ipynb | <span style="color:#008000;font-weight:bold;">FOUND</span> | 6822 | 2026-05-25 01:48:07 |

## 3. Board Files Present

| File | Status | Bytes | Last Write Time |
|---|---|---:|---|
| base_add.bit | <span style="color:#008000;font-weight:bold;">FOUND</span> | 4045674 | 2026-05-25 02:16:28 |
| base_add.hwh | <span style="color:#008000;font-weight:bold;">FOUND</span> | 326156 | 2026-05-25 02:10:52 |
| ad9226_capture_demo.ipynb | <span style="color:#008000;font-weight:bold;">FOUND</span> | 6822 | 2026-05-25 01:48:07 |
| ad9226_capture_smoke.py | <span style="color:#008000;font-weight:bold;">FOUND</span> | 6366 | 2026-05-25 01:46:49 |

Legacy notebooks may still exist in this folder for reference. Do not use them for DMA validation if they access overlay.base_add_0.

## 4. Timing Summary

Source file:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\build\vivado\base_add_overlay.runs\impl_1\system_wrapper_timing_summary_routed.rpt
~~~

| WNS ns | TNS ns | WHS ns | THS ns | Result |
|---:|---:|---:|---:|---|
| **11.128** | **0.000** | **0.028** | **0.000** | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> |

Good sign:

~~~text
All user specified timing constraints are met.
~~~

Rule: **WNS > 0** means setup timing passes.

## 5. Resource Report

Source file:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\build\vivado\base_add_overlay.runs\impl_1\system_wrapper_utilization_placed.rpt
~~~

Key lines:

~~~text
| Slice LUTs                 | 2526 |     0 |     53200 |  4.75 |
| Block RAM Tile    |  5.5 |     0 |       140 |  3.93 |
* Note: Each Block RAM Tile only has one FIFO logic available and therefore can accommodate only one FIFO36E1 or one FIFO18E1. However, if a FIFO18E1 occupies a Block RAM Tile, that tile can still accommodate a RAMB18E1
| DSPs      |    0 |     0 |       220 |  0.00 |
~~~

## 6. Vivado Project

| File | Status |
|---|---|
| build/vivado/base_add_overlay.xpr | <span style="color:#008000;font-weight:bold;">FOUND</span> |

Open this project only when you want to inspect the block design or timing in the GUI.

## 7. Next Step

If this report shows **PASS**, upload these files to PYNQ:

~~~text
pynq/base_add.bit
pynq/base_add.hwh
pynq/ad9226_capture_smoke.py
pynq/ad9226_capture_demo.ipynb
~~~

For the DMA capture path, use:

~~~text
pynq/ad9226_capture_smoke.py
pynq/ad9226_capture_demo.ipynb
~~~

Do not use old notebooks that access overlay.base_add_0 when validating DMA.
Those belong to the previous HLS-writer path and can give a false PASS.

