# Vivado Overlay Report

Generated: **2026-05-24 19:15:36**

## 1. Build Status

| Item | Status | What It Means |
|---|---|---|
| Bitstream generation | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | .bit was created |
| Copy bit to pynq folder | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | pynq/base_add.bit updated |
| Copy hwh to pynq folder | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | pynq/base_add.hwh updated |
| RTL LED controller in HWH | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | PS can discover the AXI-Lite LED IP from .hwh |
| AD9226 capture controller in HWH | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | PS can discover adc_capture_0 from hwh |
| Routed timing | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | Final implemented timing result |

## 2. Output Files For PYNQ

| File | Status | Bytes | Last Write Time |
|---|---|---:|---|
| base_add.bit | <span style="color:#008000;font-weight:bold;">FOUND</span> | 4045674 | 2026-05-24 19:12:18 |
| base_add.hwh | <span style="color:#008000;font-weight:bold;">FOUND</span> | 263959 | 2026-05-24 19:07:26 |
| ad9226_capture_demo.ipynb | <span style="color:#008000;font-weight:bold;">FOUND</span> | 3575 | 2026-05-24 19:14:38 |
| led_ctrl_demo.ipynb | <span style="color:#008000;font-weight:bold;">FOUND</span> | 2716 | 2026-05-24 17:11:25 |
| ad9226_capture_smoke.py | <span style="color:#008000;font-weight:bold;">FOUND</span> | 3332 | 2026-05-24 19:13:29 |

Upload these files to the PYNQ board after PL hardware changes.

## 3. Timing Summary

Source file:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\build\vivado\base_add_overlay.runs\impl_1\system_wrapper_timing_summary_routed.rpt
~~~

| WNS ns | TNS ns | WHS ns | THS ns | Result |
|---:|---:|---:|---:|---|
| **10.330** | **0.000** | **0.028** | **0.000** | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> |

Good sign:

~~~text
All user specified timing constraints are met.
~~~

Rule: **WNS > 0** means setup timing passes.

## 4. Resource Report

Source file:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\build\vivado\base_add_overlay.runs\impl_1\system_wrapper_utilization_placed.rpt
~~~

Key lines:

~~~text
| Slice LUTs                 | 2129 |     0 |     53200 |  4.00 |
| Block RAM Tile    |  0.5 |     0 |       140 |  0.36 |
* Note: Each Block RAM Tile only has one FIFO logic available and therefore can accommodate only one FIFO36E1 or one FIFO18E1. However, if a FIFO18E1 occupies a Block RAM Tile, that tile can still accommodate a RAMB18E1
| DSPs      |    0 |     0 |       220 |  0.00 |
~~~

## 5. Vivado Project

| File | Status |
|---|---|
| build/vivado/base_add_overlay.xpr | <span style="color:#008000;font-weight:bold;">FOUND</span> |

Open this project only when you want to inspect the block design or timing in the GUI.

## 6. Next Step

If this report shows **PASS**, upload these files to PYNQ:

~~~text
pynq/base_add.bit
pynq/base_add.hwh
pynq/ad9226_capture_demo.ipynb
pynq/led_ctrl_demo.ipynb
pynq/ad9226_capture_smoke.py
~~~

Then run one of the existing Python scripts on the board, or open an existing
notebook in the board's browser Jupyter.

