# Vivado Overlay Report

Generated: **2026-05-24 00:26:18**

## 1. Build Status

| Item | Status | What It Means |
|---|---|---|
| Bitstream generation | **PASS** | .bit was created |
| Copy bit to pynq folder | **PASS** | pynq/base_add.bit updated |
| Copy hwh to pynq folder | **PASS** | pynq/base_add.hwh updated |
| Routed timing | **PASS** | Final implemented timing result |

## 2. Output Files For PYNQ

| File | Status | Bytes | Last Write Time |
|---|---|---:|---|
| base_add.bit | FOUND | 4045674 | 2026-05-24 00:21:27 |
| base_add.hwh | FOUND | 154667 | 2026-05-24 00:18:30 |

Upload these two files to the PYNQ board after PL hardware changes.

## 3. Timing Summary

Source file:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\build\vivado\base_add_overlay.runs\impl_1\system_wrapper_timing_summary_routed.rpt
~~~

| WNS ns | TNS ns | WHS ns | THS ns | Result |
|---:|---:|---:|---:|---|
| 13.546 | 0.000 | 0.052 | 0.000 | **PASS** |

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
| Slice LUTs                 |  628 |     0 |     53200 |  1.18 |
| Block RAM Tile |    0 |     0 |       140 |  0.00 |
* Note: Each Block RAM Tile only has one FIFO logic available and therefore can accommodate only one FIFO36E1 or one FIFO18E1. However, if a FIFO18E1 occupies a Block RAM Tile, that tile can still accommodate a RAMB18E1
| DSPs           |    3 |     0 |       220 |  1.36 |
~~~

## 5. Vivado Project

| File | Status |
|---|---|
| build/vivado/base_add_overlay.xpr | **FOUND** |

Open this project only when you want to inspect the block design or timing in the GUI.

## 6. Next Step

If this report shows **PASS**, upload these files to PYNQ:

~~~text
pynq/base_add.bit
pynq/base_add.hwh
pynq/base_add_test.py
pynq/base_add_demo.ipynb
~~~

Then run **base_add_test.py** on the board, or open the notebook in the board's browser Jupyter.

