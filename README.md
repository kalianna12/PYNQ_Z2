# PYNQ-Z2 PS/PL Base Template

这是一个用于学习和后续接入 ADC/DAC 的 PYNQ-Z2 工程模板。当前工程同时包含：

```text
HLS IP   : base_add，当前作为 fake capture 示例，通过 m_axi 写 DDR buffer
RTL IP   : led_ctrl_axi，AXI-Lite 控制 PYNQ-Z2 LED0~LED3
RTL IP   : adc_capture_0，AD9226 双通道采样控制、ADC_CLK、状态寄存器
Vivado   : 自动创建 Zynq PS，连接 HLS IP、RTL IP、LED/AD9226 管脚和 DDR 通路
PYNQ     : 通过 bit/hwh + Jupyter notebook 控制 PL
```

当前 `pynq/` 文件夹已精简，只保留板端运行需要的核心文件：

```text
pynq/base_add.bit
pynq/base_add.hwh
pynq/led_ctrl_demo.ipynb
pynq/ad9226_capture_demo.ipynb
pynq/ad9226_capture_smoke.py
```

`__pycache__/` 是 Python 缓存，可以删除，也已经被 `.gitignore` 忽略。

## Directory Structure

```text
PYNQZ2_PSPL_Base/
  hls/
    src/base_add.cpp          HLS fake capture 硬件函数
    src/base_add.h            HLS 函数声明
    tb/test_base_add.cpp      HLS C 仿真 testbench
    hls.tcl                   构建 HLS IP

  rtl/
    src/led_ctrl_axi.v        手写 RTL AXI-Lite LED 控制器
    src/adc_ctrl_axi.v        AD9226 AXI-Lite 控制/状态寄存器
    src/ad9226_capture_core.v AD9226 采样时钟、采样、debug 状态
    src/adc_sample_fifo.v     32-bit sample_word 同步 FIFO
    src/adc_capture_system.v  AD9226 RTL 子系统包装
    tb/tb_led_ctrl_axi.v      RTL 仿真 testbench
    tb/tb_ad9226_capture_chain.v
    sim_led_ctrl.tcl          RTL 仿真脚本
    sim_ad9226_capture.tcl    AD9226 RTL 仿真脚本

  constraints/
    pynqz2_leds.xdc           LED0~LED3 管脚约束
    pynq_adc_system.xdc       AD9226 A/B 双通道管脚约束

  vivado/
    build.tcl                 构建 PS/PL overlay，生成 bit/hwh

  pynq/
    base_add.bit              PYNQ 加载 PL 的 bitstream
    base_add.hwh              PYNQ 识别 IP、地址、端口的硬件描述
    led_ctrl_demo.ipynb       Jupyter LED 控制演示
    ad9226_capture_demo.ipynb Jupyter AD9226 capture smoke test
    ad9226_capture_smoke.py   Python AD9226 capture smoke test

  scripts/
    Build-HlsWithReport.ps1
    Build-VivadoOverlayWithReport.ps1
    Generate-HlsReport.ps1
    Generate-RtlReport.ps1
    Generate-VivadoOverlayReport.ps1

  HLS_REPORT.md
  RTL_REPORT.md
  VIVADO_OVERLAY_REPORT.md
```

## Build Flow

在 VS Code 中打开工程根目录：

```text
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base
```

运行第 1 步：

```text
Ctrl+Shift+P
Tasks: Run Task
FPGA: 1 Build HLS IP
```

这一步会做两件事：

```text
1. 运行 HLS C 仿真、综合、导出 HLS IP
2. 运行 RTL LED 控制器 behavioral simulation
3. 运行 AD9226 capture_core + FIFO behavioral simulation
```

生成/刷新：

```text
HLS_REPORT.md
RTL_REPORT.md
```

运行第 2 步：

```text
Ctrl+Shift+P
Tasks: Run Task
FPGA: 2 Build Vivado Overlay
```

这一步会：

```text
创建 Zynq processing_system7
连接 base_add_0 HLS IP
连接 led_ctrl_0 RTL IP
连接 adc_capture_0 RTL IP
连接 HLS m_axi_GMEM 到 PS S_AXI_HP0
导出 LED0~LED3 到 PYNQ-Z2 管脚
导出 AD9226 A/B 数据、时钟、ORA/ORB 到 PYNQ-Z2 管脚
运行综合、实现、生成 bitstream
复制 bit/hwh 到 pynq/
```

生成/刷新：

```text
pynq/base_add.bit
pynq/base_add.hwh
VIVADO_OVERLAY_REPORT.md
```

## Reports

三份报告分工如下：

```text
HLS_REPORT.md
  只看 HLS：C 仿真、HLS timing、latency、resource、HLS 寄存器偏移

RTL_REPORT.md
  只看手写 RTL：RTL 源文件、testbench、仿真 PASS/FAIL、RTL 寄存器表、LED 管脚约束

VIVADO_OVERLAY_REPORT.md
  看最终集成：bit/hwh 是否生成、RTL IP 是否进入 hwh、最终 WNS/时序、资源摘要、当前 pynq 文件列表
```

重点判断：

```text
HLS_REPORT.md              C simulation PASS, Timing PASS, IP export PASS
RTL_REPORT.md              RTL sim PASS
VIVADO_OVERLAY_REPORT.md   Bitstream PASS, Routed timing PASS, WNS > 0
```

报告可单独刷新：

```text
FPGA: Generate HLS Report Only
FPGA: Generate RTL Report Only
FPGA: Generate Vivado Overlay Report Only
```

## PYNQ Board Run

上传当前 `pynq/` 下的文件到 PYNQ 板：

```text
base_add.bit
base_add.hwh
led_ctrl_demo.ipynb
ad9226_capture_demo.ipynb
ad9226_capture_smoke.py
```

打开 PYNQ 浏览器 Jupyter：

```text
http://192.168.2.99:9090
```

打开并运行：

```text
led_ctrl_demo.ipynb
```

它会加载 `base_add.bit`，从 `base_add.hwh` 自动读取 `led_ctrl_0` 的真实 AXI-Lite 地址，然后切换 LED 模式。

当前 Vivado 生成日志里 `led_ctrl_0` 的真实基地址是：

```text
0x43C10000
```

当前 Vivado/HWH 里 `adc_capture_0` 的真实基地址是：

```text
0x43C20000
```

但 Python / ipynb 中不要硬编码这个基地址，优先从 `.hwh` / `overlay.ip_dict` 获取。

AD9226 不接真实 ADC 时，先运行：

```text
ad9226_capture_demo.ipynb
```

它使用 `capture_mode=2`，由 capture_core 生成 fake stream，验证：

```text
PS -> adc_capture_0 AXI-Lite
capture_core
sample_word/FIFO
status/debug registers
ADC_CLK 输出控制
```

## Current Register Maps

### RTL LED Controller

这是 RTL 模块内部 offset，真实 base address 以 `.hwh` / Vivado 日志为准。

```text
0x00 CTRL        bit0 enable, bits[3:1] mode
0x04 SPEED_DIV   blink/walk/counter 分频
0x08 LED_VALUE   手动 LED 值，bits[3:0]
0x0C STATUS      bits[3:0] 当前 LED，bits[7:4] tick counter
```

模式：

```text
0 direct
1 blink
2 walk
3 counter
```

### HLS Fake Capture

HLS 寄存器偏移以生成文件为准：

```text
hls/base_add_prj/solution1/impl/misc/drivers/base_add_v1_0/src/xbase_add_hw.h
```

当前常用 offset：

```text
0x00 AP_CTRL
0x10 BUFFER_R_DATA
0x18 SAMPLE_COUNT_DATA
0x20 CAPTURE_MODE_DATA
```

### AD9226 Capture Controller

这是 `adc_capture_0` 内部 offset，PYNQ 中用 `ctrl.write(offset, value)`，不要加 `0x43C20000` 基地址。

```text
0x00 CTRL          bit0 enable, bit1 start pulse, bit2 clear pulse, bit6 soft_reset
0x04 STATUS        busy/done/adc_clk_seen/fifo/error/data_changed
0x08 SAMPLE_COUNT  本次保存样本数
0x0C ADC_HALF      ADC clock half period
0x10 SAMPLE_DELAY  125MHz 周期数
0x14 DECIMATION    每 N 个 ADC 样本保存 1 个
0x18 CHANNEL_MASK  bit0=A, bit1=B
0x1C CAPTURE_MODE  0 writer fake, 1 real AD9226, 2 capture_core fake stream
0x2C LATEST_A
0x30 LATEST_B
0x34 SAMPLE_COUNTER
0x38 FIFO_LEVEL
0x3C ERROR_FLAGS
0x44 VERSION
0x48 SAVED_COUNTER
0x4C LAST_SAMPLE_WORD
0x50 DEBUG_STATE
```

## What To Edit

开发 HLS fake capture / 后续 HLS 采样搬运：

```text
hls/src/base_add.cpp
hls/src/base_add.h
hls/tb/test_base_add.cpp
```

开发手写 RTL / 后续 ADC 采样状态机：

```text
rtl/src/*.v
rtl/tb/*.v
rtl/sim_*.tcl
constraints/*.xdc
```

开发 PYNQ 端控制、分析、画图：

```text
pynq/*.ipynb
pynq/*.py
```

不要手动编辑这些生成目录：

```text
hls/base_add_prj/
build/
.Xil/
```

不要编辑 Xilinx 安装目录里的库文件，例如：

```text
G:\Xilinx\Vivado\2018.2\include\ap_int.h
```

## When To Rebuild

改这些，需要重新跑第 1 步和第 2 步：

```text
hls/src/*.cpp
hls/src/*.h
hls/tb/*.cpp
rtl/src/*.v
rtl/tb/*.v
constraints/*.xdc
vivado/build.tcl
HLS 函数端口
HLS pragma
RTL 模块端口
```

只改这些，不需要重新生成 bit/hwh：

```text
pynq/*.py
pynq/*.ipynb
Python 数据分析
Jupyter 显示逻辑
```

## Development Habit

1. 先写 testbench。
2. 先跑 `FPGA: 1 Build HLS IP`，确认 HLS/RTL 仿真 PASS。
3. 再跑 `FPGA: 2 Build Vivado Overlay`，确认 bitstream 和 WNS PASS。
4. 再上传 `pynq/` 文件到板子。
5. Python/ipynb 遇到地址，优先查 `.hwh`、Vivado 日志、HLS 生成头文件，不靠猜。

下一步真实接 AD9226 时，先用 `capture_mode=2` 确认内部链路，再切到 `capture_mode=1` 读真实管脚。
