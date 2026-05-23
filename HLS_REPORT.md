# HLS Report

Generated: **2026-05-24 00:37:33**

## 1. Build Status

| Item | Status | What It Means |
|---|---|---|
| C simulation | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | Testbench result |
| Timing estimate | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | Estimated clock should be smaller than target |
| IP export | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> | Vivado can import this HLS IP |
| Vivado 2018.2 date workaround | <span style="color:#b26a00;font-weight:bold;">USED</span> | Normal for old Vivado on modern dates |

## 2. C Simulation

Source file:

~~~text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base\hls\base_add_prj\solution1\csim\report\base_add_csim.log
~~~

Key result:

~~~text
PASS
INFO: [SIM 1] CSim done with 0 errors.
~~~

## 3. Timing

| Clock | Target ns | Estimated ns | Result |
|---|---:|---:|---|
| ap_clk | **10.00** | **8.510** | <span style="color:#008000;font-weight:bold;font-size:16px;">PASS</span> |

Rule: **Estimated < Target** means the HLS estimate is acceptable.

## 4. Latency

| Latency min | Latency max | Interval min | Interval max |
|---:|---:|---:|---:|
| **2** | **2** | **2** | **2** |

## 5. Resource Estimate

| BRAM_18K | DSP48E | FF | LUT |
|---:|---:|---:|---:|
| 0 | 3 | 290 | 577 |

## 6. Generated IP

| File | Status |
|---|---|
| hls/base_add_prj/solution1/impl/ip/component.xml | <span style="color:#008000;font-weight:bold;">FOUND</span> |
| hls/base_add_prj/solution1/impl/ip/xilinx_com_hls_base_add_1_0.zip | <span style="color:#008000;font-weight:bold;">FOUND</span> |

## 7. AXI-Lite Register Addresses

Read these addresses in Python with ip.write() and ip.read().

~~~text
#define XBASE_ADD_CTRL_ADDR_AP_CTRL       0x00
#define XBASE_ADD_CTRL_ADDR_GIE           0x04
#define XBASE_ADD_CTRL_ADDR_IER           0x08
#define XBASE_ADD_CTRL_ADDR_ISR           0x0c
#define XBASE_ADD_CTRL_ADDR_A_V_DATA      0x10
#define XBASE_ADD_CTRL_ADDR_B_V_DATA      0x18
#define XBASE_ADD_CTRL_ADDR_MODE_V_DATA   0x20
#define XBASE_ADD_CTRL_ADDR_RESULT_V_DATA 0x28
#define XBASE_ADD_CTRL_ADDR_RESULT_V_CTRL 0x2c
~~~

## 8. Next Step

If this report shows **PASS**, run:

~~~text
FPGA: 2 Build Vivado Overlay
~~~

