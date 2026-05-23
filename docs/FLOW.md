PYNQ-Z2 PS/PL 学习流程
1. 每个部分是什么意思

PS 指的是 PYNQ-Z2 板卡上运行 Linux 和 Python 的 ARM 处理器。

PL 指的是 FPGA 逻辑资源。你的 HLS C/C++ 或 Verilog 代码会被转换成 PL 内部的硬件电路。

常见的入门流程是：

HLS C/C++ -> HLS IP -> Vivado block design -> bit/hwh -> PYNQ Python

也就是：

HLS C/C++ -> HLS IP 核 -> Vivado 块设计 -> bit/hwh 文件 -> PYNQ Python 调用
2. 通常需要编辑的文件

最常编辑的是这些文件：

hls/src/base_add.cpp
hls/src/base_add.h
hls/tb/test_base_add.cpp
pynq/base_add_test.py

生成文件位于：

hls/base_add_prj/
build/
pynq/base_add.bit
pynq/base_add.hwh

不要手动编辑生成文件，除非只是查看报告。

3. 构建命令

在 PowerShell 中执行：

cd G:\VSCODE_Save_Files\PYNQ_Z2Code\PYNQZ2_PSPL_Base
$env:DEBUG=''
& 'G:\Xilinx\Vivado\2018.2\bin\vivado_hls.bat' -f hls\hls.tcl
& 'G:\Xilinx\Vivado\2018.2\bin\vivado.bat' -mode batch -source vivado\build.tcl

在 VS Code 中：

Ctrl+Shift+P -> Tasks: Run Task -> FPGA: 1 Build HLS IP
Ctrl+Shift+P -> Tasks: Run Task -> FPGA: 2 Build Vivado Overlay
4. PS 如何与 PL 通信

HLS 代码使用 AXI-Lite 接口：

#pragma HLS INTERFACE s_axilite port=a bundle=CTRL
#pragma HLS INTERFACE s_axilite port=b bundle=CTRL
#pragma HLS INTERFACE s_axilite port=result bundle=CTRL
#pragma HLS INTERFACE s_axilite port=return bundle=CTRL

Vivado 中的连接关系是：

PS M_AXI_GP0 -> AXI interconnect -> base_add_0/s_axi_CTRL

Python 通过寄存器读写控制 IP：

ip.write(0x10, a)
ip.write(0x18, b)
ip.write(0x00, 0x01)
result = ip.read(0x20)
5. 在哪里查看结果

HLS C 仿真结果：

hls/base_add_prj/solution1/csim/report/base_add_csim.log

HLS 综合报告：

hls/base_add_prj/solution1/syn/report/base_add_csynth.rpt

Vivado 实现后的时序报告：

build/vivado/base_add_overlay.runs/impl_1/system_wrapper_timing_summary_routed.rpt

Vivado 资源使用报告：

build/vivado/base_add_overlay.runs/impl_1/system_wrapper_utilization_placed.rpt
6. 良好的开发习惯

推荐使用下面的开发循环：

1. 修改 HLS C/C++
2. 运行 C 仿真
3. 运行 HLS 综合
4. 检查延迟、II 和资源使用情况
5. 导出 IP
6. 只有当 PL 硬件发生变化时，才重新构建 Vivado overlay
7. 将 bit/hwh 复制到 PYNQ
8. 在 Python/Jupyter 中调试

如果只修改了 Python 代码，不要重新运行 Vivado。

如果只修改了输入值或寄存器访问逻辑，就在 PYNQ/Jupyter 上调试。

如果修改了 HLS pragma、函数端口、数组大小或硬件逻辑，则需要重新运行 HLS 和 Vivado。    、