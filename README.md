# PYNQ-Z2 PS/PL 基础模板

这是一个干净的 PYNQ-Z2 PS + PL 项目学习模板。

PL 端包含一个简单的 HLS IP：

```text
result = a + b
```

Vivado 会自动把 Zynq PS 的 AXI 主接口连接到这个 HLS IP。PYNQ 端加载生成的 `.bit` 和 `.hwh` 文件，然后通过 Python 寄存器读写来控制该 IP。

## 目录结构

```text
PYNQZ2_PSPL_Base/
  hls/
    src/base_add.cpp       HLS 硬件函数
    src/base_add.h         HLS 函数声明
    tb/test_base_add.cpp   C 仿真测试平台
    hls.tcl                构建 HLS IP
  vivado/
    build.tcl              构建 PS/PL overlay，并导出 bit/hwh
  pynq/
    base_add_test.py       PYNQ 板/Jupyter 的 Python 测试脚本
    base_add_demo.ipynb    简单的 Jupyter Notebook
  docs/
    FLOW.md                分步骤学习笔记
  .vscode/
    tasks.json             VS Code 构建任务
```

## 在 Windows 上构建

用 VS Code 打开这个文件夹，然后运行：

```text
Ctrl+Shift+P -> Tasks: Run Task -> FPGA: 1 Build HLS IP
Ctrl+Shift+P -> Tasks: Run Task -> FPGA: 2 Build Vivado Overlay
```

生成的板端文件会被复制到：

```text
pynq/base_add.bit
pynq/base_add.hwh
```

## 在 PYNQ-Z2 上运行

把 `pynq/` 文件夹中的内容复制到你的 PYNQ 板上，然后运行：

```bash
python3 base_add_test.py
```

或者在 Jupyter 中打开 `base_add_demo.ipynb`。

## 初学者工作流程

这个项目用于学习最小的 PS + PL 开发闭环：

```text
编写 HLS C/C++
-> 运行 HLS 仿真和综合
-> 导出 HLS IP
-> 运行 Vivado 连接 PS 和 PL
-> 生成 bit/hwh
-> 在 PYNQ 上运行 Python 或 Jupyter
```

PS 是 PYNQ-Z2 板上的 ARM 处理器。它运行 Linux、Python 和 Jupyter。

PL 是 FPGA 可编程逻辑区域。你的 HLS C/C++ 代码会在 PL 中变成真实硬件。

在这个基础项目中，PL 硬件是：

```cpp
*result = a + b;
```

PS 端用 Python 控制它：

```python
ip.write(0x10, a)
ip.write(0x18, b)
ip.write(0x00, 0x01)
result = ip.read(0x20)
```

含义如下：

```text
0x10: 输入 a
0x18: 输入 b
0x00: 控制寄存器，写入 1 表示启动
0x20: 输出 result
```

## 你需要编辑的文件

通常编辑这些文件：

```text
hls/src/base_add.cpp        PL 硬件函数
hls/src/base_add.h          PL 函数声明
hls/tb/test_base_add.cpp    HLS C 仿真测试平台
pynq/base_add_test.py       PYNQ 上的 Python 测试
pynq/base_add_demo.ipynb    PYNQ 上的 Jupyter Notebook
```

不要手动编辑这些生成文件夹：

```text
hls/base_add_prj/
build/
```

不要编辑 Xilinx 库文件，例如：

```text
G:\Xilinx\Vivado\2018.2\include\ap_int.h
```

## VS Code 中的命令

打开这个文件夹：

```powershell
G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base
```

运行 HLS：

```text
Ctrl+Shift+P
Tasks: Run Task
FPGA: 1 Build HLS IP
```

等价的 PowerShell 命令：

```powershell
cd G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base
$env:DEBUG=''
& 'G:\Xilinx\Vivado\2018.2\bin\vivado_hls.bat' -f hls\hls.tcl
```

完成这一步后，检查是否出现：

```text
PASS
CSim done with 0 errors
Finished C synthesis
```

主要生成文件：

```text
hls/base_add_prj/solution1/syn/report/base_add_csynth.rpt
hls/base_add_prj/solution1/impl/ip/
```

运行 Vivado overlay 构建：

```text
Ctrl+Shift+P
Tasks: Run Task
FPGA: 2 Build Vivado Overlay
```

等价的 PowerShell 命令：

```powershell
& 'G:\Xilinx\Vivado\2018.2\bin\vivado.bat' -mode batch -source vivado\build.tcl
```

完成这一步后，检查是否出现：

```text
Bitgen Completed Successfully
Copied bitstream to ...\pynq\base_add.bit
Copied handoff to ...\pynq\base_add.hwh
```

主要生成文件：

```text
pynq/base_add.bit
pynq/base_add.hwh
build/vivado/base_add_overlay.xpr
```

## 什么时候需要重新生成

如果你修改了 `hls/src/base_add.cpp` 中的 PL 硬件逻辑，需要重新运行：

```text
FPGA: 1 Build HLS IP
FPGA: 2 Build Vivado Overlay
```

然后把新的文件上传到 PYNQ：

```text
pynq/base_add.bit
pynq/base_add.hwh
```

如果你只修改 Python 或 Jupyter 代码，不需要重新运行 HLS 或 Vivado。只需要上传修改后的 `.py` 或 `.ipynb` 文件。

如果你修改了 `base_add.h` 中的函数端口，或者修改了 HLS interface pragma，需要重新运行 HLS 和 Vivado。你可能还需要检查新的寄存器地址，位置在：

```text
hls/base_add_prj/solution1/impl/misc/drivers/base_add_v1_0/src/xbase_add_hw.h
```

## 如何检查设计

检查 HLS C 仿真：

```text
hls/base_add_prj/solution1/csim/report/base_add_csim.log
```

查找：

```text
PASS
CSim done with 0 errors
```

检查 HLS 综合报告：

```text
hls/base_add_prj/solution1/syn/report/base_add_csynth.rpt
```

重点查看：

```text
Timing
Latency
Utilization Estimates
Interface
```

检查 Vivado 实现后的时序：

```text
build/vivado/base_add_overlay.runs/impl_1/system_wrapper_timing_summary_routed.rpt
```

好的标志是：

```text
WNS > 0
All user specified timing constraints are met.
```

检查 PYNQ 运行结果：

```bash
python3 base_add_test.py
```

好的标志是：

```text
PASS
```

## 练习 1

目标：把 PL 硬件从加法改成乘法。

1. 编辑 `hls/src/base_add.cpp`。

把：

```cpp
*result = a + b;
```

改成：

```cpp
*result = a * b;
```

2. 编辑 `hls/tb/test_base_add.cpp`。

把期望结果从 `579` 改为：

```cpp
123 * 456
```

3. 运行：

```text
FPGA: 1 Build HLS IP
```

确认 C 仿真通过。

4. 运行：

```text
FPGA: 2 Build Vivado Overlay
```

确认新的 `base_add.bit` 和 `base_add.hwh` 已生成。

5. 编辑 `pynq/base_add_test.py`。

修改打印文本或断言，让它检查乘法结果：

```python
assert result == a * b
```

6. 把新文件上传到 PYNQ：

```text
base_add.bit
base_add.hwh
base_add_test.py
```

7. 在 PYNQ 上运行：

```bash
python3 base_add_test.py
```

预期结果：

```text
123 * 456 = 56088
PASS
```

## Auto Summary Reports

The VS Code build tasks now generate readable summary reports automatically.

After running:

```text
FPGA: 1 Build HLS IP
```

open this file in the project root:

```text
HLS_REPORT.md
```

It summarizes C simulation, HLS timing, latency, resource estimate, exported IP
files, and AXI-Lite register addresses.

After running:

```text
FPGA: 2 Build Vivado Overlay
```

open this file in the project root:

```text
VIVADO_OVERLAY_REPORT.md
```

It summarizes bitstream generation, `base_add.bit` / `base_add.hwh` update time,
final routed timing, resource usage, and the next PYNQ upload step.

You can regenerate reports without rebuilding:

```text
Ctrl+Shift+P -> Tasks: Run Task -> FPGA: Generate HLS Report Only
Ctrl+Shift+P -> Tasks: Run Task -> FPGA: Generate Vivado Overlay Report Only
```

The original Vivado/HLS logs are kept unchanged. Read the summary reports first,
and open raw `.log` or `.rpt` files only when something fails.

## Jupyter Note

You do not need the VS Code Jupyter extension to run this project on PYNQ.

For board testing, use the PYNQ web page in your browser:

```text
http://192.168.2.99:9090
```

Then upload and open:

```text
base_add_demo.ipynb
```

The VS Code Jupyter extension is only for viewing or editing notebooks on the PC
side. It is optional.
