# AD9226 AXI DMA Capture Plan

本文档描述当前 PYNQ-Z2 + AD9226 双通道采样工程从 HLS m_axi writer 迁移到 AXI DMA S2MM 的优化路线。目标是提高 `decimation=1` 时的完整保存率，同时保持当前已验证的 AD9226 管脚、采样时序和 31.25MHz PL FCLK 不变。

本次只写设计方案，不写 Verilog / TCL / Python 代码。

## 1. 当前已验证结果

当前工程已经验证三条链路：

| 模式 | 数据路径 | 结果 |
|---|---|---|
| mode 0 | HLS fake -> DDR -> PS/Python | PASS |
| mode 2 | RTL fake stream -> FIFO -> HLS writer -> DDR -> PS/Python | PASS |
| mode 1 | AD9226 real ADC -> FIFO -> HLS writer -> DDR -> PS/Python | PASS |

真实硬件侧也已经验证：

- STM32 PA5 输出 0 / 3.3V 方波，可以被 AD9226 采到。
- 该信号实际进入当前系统 CH1。
- AD9226 XDC 管脚已经验证可用，本阶段不修改。
- 当前 PL FCLK 实测为 31.25MHz，不是 125MHz。
- 第一版 AXI DMA 优化不提高 PL 时钟，先在 31.25MHz 下验证。

当前 HLS writer 版本稳定范围大致为：

| adc_half_period | decimation | 实际 ADC Fs | 结果 |
|---:|---:|---:|---|
| 12 | 1 | 31.25MHz / (2 * 12) = 1.302MSPS | PASS |
| 6 | 1 | 31.25MHz / (2 * 6) = 2.604MSPS | PASS |
| 3 | 1 | 31.25MHz / (2 * 3) = 5.208MSPS | FIFO overflow / writer timeout |
| 1 | 8 | 31.25MHz / 2 / 8 = 1.953MSPS 有效保存率 | 可运行 |

结论：AD9226 采样链路已经能工作，瓶颈主要在 `FIFO -> HLS writer -> DDR` 写入路径。

## 2. 当前瓶颈分析

当前现象说明：

- AD9226 采样侧可以采到真实信号。
- mode 2 fake stream 能经过 RTL FIFO 和 HLS writer 写入 DDR。
- mode 1 real ADC 能在低保存率下写入 DDR。
- 当 `adc_half_period` 变小、`decimation=1` 时，出现 FIFO overflow 或 writer timeout。

这意味着上游 capture 产生数据的速度超过下游 HLS writer 消费速度。`decimation=8` 能跑 `hp=1`，是因为实际保存率降低了，不代表完整保存能力足够。

当前 HLS writer 还采用双分区 DDR 布局：

```text
buffer[0 ... N-1] = CH0
buffer[MAX_SAMPLE_N ... MAX_SAMPLE_N+N-1] = CH1
```

该布局便于 Python 切片，但 HLS 每个 sample 要写两个相距较远的位置，对 AXI burst 不友好，也容易导致 writer loop 不能稳定达到 II=1。

要提高完整保存率，推荐将：

```text
FIFO -> HLS m_axi writer -> DDR
```

替换为：

```text
AXI-Stream -> AXIS Data FIFO -> AXI DMA S2MM -> DDR
```

DMA 改造只替换 stream-to-DDR 路径，不应修改已验证的 AD9226 XDC、ODDR/采样时钟输出、输入数据打拍、`adc_half_period` 和 `sample_delay` 逻辑。

## 3. 新架构总览

推荐数据路径：

```text
AD9226 pins
  -> ad9226_capture_axis
  -> AXI-Stream 32-bit packed samples
  -> AXIS Data FIFO
  -> AXI DMA S2MM
  -> PS DDR
  -> PYNQ Python unpack / plot / analysis
```

控制路径：

```text
PS/Python
  -> adc_capture AXI-Lite registers
  -> configure sample_count / adc_half_period / decimation / channel_mask / capture_mode
  -> start AXI DMA receive
  -> start capture
  -> wait DMA complete
  -> invalidate buffer
  -> unpack CH0/CH1
```

核心变化：

- HLS writer 不再作为 DDR 写入主路径。
- DMA 版 Vivado BD 中旧 HLS writer 可以保留但不得参与新数据路径；PYNQ notebook 也不应再访问 `base_add_0` writer 寄存器。
- RTL capture 直接输出 AXI-Stream。
- AXIS Data FIFO 负责短时缓冲和吸收 DMA backpressure。
- AXI DMA S2MM 负责连续写 DDR。
- DDR 中存储 packed `uint32`，每个 word 是一个双通道采样点。

## 4. 数据格式设计

每个双通道采样点打包为一个 `uint32`：

| bit range | 含义 |
|---|---|
| bits[11:0] | CH0 / AD9226 A raw code |
| bits[15:12] | 0，第一版保留 |
| bits[27:16] | CH1 / AD9226 B raw code |
| bits[31:28] | 0，第一版保留 |

即：

```text
sample_word[11:0]   = CH0 / A
sample_word[15:12]  = 0
sample_word[27:16]  = CH1 / B
sample_word[31:28]  = 0
```

`SAMPLE_COUNT` 的定义必须明确：

- `SAMPLE_COUNT` = 需要输出到 DMA 的 packed `sample_word` 数。
- 它不是 ADC 原始采样次数。
- DMA 传输字节数 = `SAMPLE_COUNT * 4`。
- `SAMPLE_CNTR` = ADC 原始采样边沿计数。
- `AXIS_SENT_COUNT` = 已经成功送入 DMA/FIFO 链路的 packed `sample_word` 数。
- capture done 条件 = `AXIS_SENT_COUNT == SAMPLE_COUNT`，且最后一次握手带 `TLAST`。
- `SAVED_COUNTER` 只是 capture_core 侧“尝试产生保存点”的计数。遇到下游
  backpressure/drop 时，它可能等于 `SAMPLE_COUNT`，但 DMA 实际并未完整收到数据。
  DMA 版成功判据不能使用 `SAVED_COUNTER == SAMPLE_COUNT`。

例如：

```text
SAMPLE_COUNT = 32768
DECIMATION   = 8

目标输出到 DMA 的 packed word 数 = 32768
实际 ADC 原始采样计数约为 32768 * 8
```

Python 端读取方式：

```text
buf = allocate(shape=(sample_count,), dtype=np.uint32)
raw = np.array(buf, dtype=np.uint32)
ch0 = raw & 0x0FFF
ch1 = (raw >> 16) & 0x0FFF
```

不要再使用旧 HLS writer 的 `2 * MAX_SAMPLE_N`、`int32` 双分区 buffer。DMA 版第一阶段固定使用 packed `np.uint32` buffer。

Python 应按 `np.uint32` 读取，不按 byte array 手动拼接，避免端序歧义。

## 5. AXI-Stream 接口设计

`ad9226_capture_axis` 输出 AXI-Stream：

| 信号 | 方向 | 含义 |
|---|---|---|
| `m_axis_tdata[31:0]` | output | packed sample_word |
| `m_axis_tvalid` | output | sample_word 有效 |
| `m_axis_tready` | input | 下游 AXIS FIFO 可接收 |
| `m_axis_tlast` | output | 本次 capture 最后一个样本 |
| `m_axis_tkeep[3:0]` | output | 如果 DMA/FIFO 启用 TKEEP，则固定为 `4'b1111` |

规则：

1. 只有 `tvalid && tready` 时，才算一个样本真正送出。
2. `AXIS_SENT_COUNT` 只在 `tvalid && tready` 时加一。
3. 第 `SAMPLE_COUNT` 个成功送出的样本必须带 `tlast=1`。
4. `TLAST` 必须和最后一个有效样本同拍握手。
5. 如果 `tvalid=1` 但 `tready=0`，`AXIS_STALL_COUNT` 加一。
6. `tready=0` 时，`tdata`、`tlast`、`tkeep` 必须保持稳定，直到握手成功。
7. 如果 AXI DMA S_AXIS_S2MM 端启用 TKEEP/TSTRB，则 capture 或中间转换模块必须提供 `tkeep=4'b1111`，表示 4 字节全部有效。

Simple DMA S2MM 同时依赖 BTT / transfer length 和 TLAST。实际收到的数据量、TLAST 位置和 DMA transfer size 必须一致。第 `SAMPLE_COUNT` 个 word 才能打 TLAST，DMA transfer length 必须是 `SAMPLE_COUNT * 4` bytes。TLAST 提前或延后，都可能导致 `dma.recvchannel.wait()` 卡住、DMA error 或数据长度异常。

### Backpressure 与真实 ADC 连续采样

AXI-Stream 规则要求 `tready=0` 时不能改变当前待发送 word。但真实 AD9226 采样时钟不会因为 DMA backpressure 自动停下来，因此需要明确策略。

推荐第一版策略：

- capture_core 只在下游 ready 时提交保存样本。
- 如果 `m_axis_tready=0`，保持当前待发送 `tdata/tlast/tkeep`，不继续消耗新的保存样本。
- 同时记录 `AXIS_STALL_COUNT` 和 `FIFO_BACKPRESSURE_SEEN`。
- 如果 stall 超过阈值，置 `backpressure_overflow` 或 `dropped_sample` 错误。

这意味着一旦发生较长 backpressure，真实 ADC 中间的连续样本可能无法完整保存。严格意义上的“完整保存 PASS”不仅要求 DMA wait 返回，还要求：

```text
AXIS_SENT_COUNT == SAMPLE_COUNT
TLAST_COUNT == 1
无 dropped_sample / axis_overflow
```

如果出现 stall 但没有丢点，DMA 传输本身可能完整；但对真实连续 ADC 来说，除非前级有足够缓存承接所有新样本，否则不能宣称“无停顿连续保存”。

`AXIS_STALL_COUNT` 是性能指标，不一定直接等于丢样。如果 `STALL>0` 但 `DROPPED_SAMPLE_COUNT=0` 且 `axis_overflow=0`，DMA 传输仍可视为完整，但说明系统接近吞吐边界。第一版做高标准测试时，可以把 `AXIS_STALL_COUNT=0` 和 `FIFO_BACKPRESSURE_SEEN=0` 作为“严格连续保存”的附加判据。

### AXIS Data FIFO 的位置

新架构中，capture_axis 的 `tready` 接的是 `axis_data_fifo_0/S_AXIS_TREADY`，不是 DMA 直接返回的 ready。

```text
capture_axis/M_AXIS
  -> axis_data_fifo_0/S_AXIS
  -> axis_data_fifo_0/M_AXIS
  -> axi_dma_0/S_AXIS_S2MM
```

因此：

- 只要 AXIS FIFO 未满，capture_axis 通常不会被 backpressure。
- 如果 AXIS FIFO 满，`S_AXIS_TREADY=0`，capture_axis 必须保持当前 `tdata/tlast`。
- FIFO 满说明 DMA/DDR 路径长期跟不上，应该置错误或至少置 backpressure 标志。

第一版 AXIS Data FIFO 深度建议：

```text
FIFO depth = 4096 或 8192 words
FIFO storage = BRAM
TDATA width = 32
TLAST enabled
TKEEP enabled if DMA requires it
```

AXIS Data FIFO 必须传递 TLAST；如果使用 TKEEP，也必须传递 TKEEP。

## 6. AXI DMA Vivado BD 连接方案

新增 Vivado IP：

- `axi_dma_0`
- `axis_data_fifo_0`

推荐连接：

```text
ad9226_capture_axis/M_AXIS
  -> axis_data_fifo_0/S_AXIS

axis_data_fifo_0/M_AXIS
  -> axi_dma_0/S_AXIS_S2MM

axi_dma_0/M_AXI_S2MM
  -> processing_system7_0/S_AXI_HP0

axi_dma_0/S_AXI_LITE
  -> processing_system7_0/M_AXI_GP0

adc_capture_axis/S_AXI
  -> processing_system7_0/M_AXI_GP0
```

DMA 配置建议：

| 配置项 | 建议 |
|---|---|
| Scatter Gather | 关闭 |
| MM2S | 关闭 |
| S2MM | 开启 |
| Stream Data Width | 32 |
| Memory Map Data Width | 32 或 64 |
| Buffer Length Register Width | 至少支持 262144 bytes，建议 23 bits 或更高 |
| Clock | 第一版统一使用当前 31.25MHz PL clock |

`sample_count=65536` 时：

```text
bytes = 65536 * 4 = 262144 bytes
```

因此 DMA buffer length register 必须覆盖至少 262144 bytes。建议设置为 23 bits 或更高，为后续更大 buffer 留余量。

### 时钟与复位

第一版不引入多时钟域，以下端口都接同一个 FCLK：

- `adc_capture_axis/aclk`
- `axis_data_fifo_0/s_axis_aclk`
- `axis_data_fifo_0/m_axis_aclk`
- `axi_dma_0/s_axi_lite_aclk`
- `axi_dma_0/m_axi_s2mm_aclk`
- `processing_system7_0/S_AXI_HP0_ACLK`

复位建议：

- 所有 AXI IP 的 `aresetn` 使用 `proc_sys_reset/peripheral_aresetn`。
- 自定义 RTL 使用同一个 active-low reset，或在模块内部做同步 reset。
- 避免同一条数据路径混用多个无约束 reset。

### DMA 中断

第一版可以不依赖 DMA interrupt，PS 端使用 `dma.recvchannel.wait()` 或状态轮询。

如果 PYNQ overlay 识别或 DMA driver 使用需要，可将：

```text
axi_dma_0/s2mm_introut -> processing_system7_0/IRQ_F2P
```

但第一版功能验证的核心不是中断，而是 S2MM 数据流和 `dma.wait()` 返回。

Vivado BD 必须确认：

- `processing_system7_0` 已启用 `S_AXI_HP0`。
- `axi_dma_0/M_AXI_S2MM` 通过 AXI interconnect 或 SmartConnect 接入 `processing_system7_0/S_AXI_HP0`。
- `S_AXI_HP0_ACLK` 接当前 FCLK。
- address map 已成功分配，AXI DMA S_AXI_LITE 能被 PS 访问。

### PYNQ IP 名称

PYNQ 端不要硬编码假设 DMA 名称一定是 `axi_dma_0`。Notebook 第一格必须打印：

```text
overlay.ip_dict.keys()
```

以实际 HWH 里的名字为准，例如 `overlay.axi_dma_0`、`overlay.axi_dma` 或 Vivado 自动生成的其他实例名。

## 7. AXI-Lite 寄存器兼容性

尽量保留现有 adc_capture AXI-Lite 寄存器，避免 PS 端改动过大。

建议保留：

| 寄存器 | 作用 |
|---|---|
| `CTRL` | enable / start / clear / soft_reset |
| `STATUS` | busy / done / adc_clk_seen / fifo / error |
| `SAMPLE_COUNT` | 本次要输出到 DMA 的 packed sample_word 数 |
| `ADC_HALF` | AD9226 采样时钟半周期 |
| `SAMPLE_DELAY` | 采样延迟 |
| `DECIMATION` | 每 N 个 ADC 原始样本保存 1 个 |
| `CHANNEL_MASK` | CH0/CH1 字段使能 |
| `CAPTURE_MODE` | 1 real ADC，2 RTL fake stream |
| `TRIGGER_MODE` | 第一版 software trigger |
| `PRE_DELAY` | start 后预延迟 |
| `ERROR_FLAGS` | 错误标志，建议 W1C |
| `LATEST_A` | 最近 A 通道 raw code |
| `LATEST_B` | 最近 B 通道 raw code |
| `SAMPLE_CNTR` | ADC 原始采样计数 |
| `VERSION` | 硬件版本号 |

建议新增：

| 寄存器 | 作用 |
|---|---|
| `AXIS_SENT_COUNT` | 成功 AXI-Stream 握手送出的 packed sample_word 数 |
| `AXIS_STALL_COUNT` | `tvalid=1 && tready=0` 的 stall 周期数 |
| `TLAST_COUNT` | 成功送出的 TLAST 次数 |
| `LAST_AXIS_WORD` | 最近成功握手送出的 packed sample_word |
| `FIFO_BACKPRESSURE_SEEN` | 是否遇到 FIFO/DMA backpressure |
| `CAPTURE_DONE_LATCHED` | capture 完成并锁存 |
| `DROPPED_SAMPLE_COUNT` | 因 backpressure 无法完整保存而丢弃/跳过的样本数 |

### STATUS / ERROR_FLAGS 分级

不要把所有状态都当作致命错误。

真正导致本次 capture FAIL 的错误：

- `axis_overflow`
- `dropped_sample`
- `TLAST_COUNT != 1`
- `AXIS_SENT_COUNT != SAMPLE_COUNT`
- `dma wait timeout`
- FIFO overflow / AXIS FIFO full too long

仅作为提示/警告的状态：

- `near_rail_a/b`
- `data_changed_a/b`
- latest sample debug flags

如果旧版常见 `ERROR_FLAGS=0x0C` 是 near rail / data 状态，不应直接误判为 DMA 失败。DMA 版文档和代码应明确 fatal error 与 warning/debug status。

### CTRL.start / clear 行为

`CTRL.start` 建议设计为写 1 触发的启动脉冲，或软件写 1 后硬件自动清零。避免 start 电平长期保持导致重复 capture。

推荐 PS 写法：

```text
write CTRL enable
write CTRL enable | start
write CTRL enable
```

一次 capture 完成后，状态机进入 DONE，等待 clear 或下一次 start 前的重新初始化。下一次 capture 前必须清：

- `AXIS_SENT_COUNT`
- `AXIS_STALL_COUNT`
- `TLAST_COUNT`
- `done`
- `busy`
- fatal error flags
- FIFO 残留状态

第一版不做硬件 continuous streaming，但必须支持 PS 连续多次 single-shot capture：

```text
DMA transfer -> start capture -> wait -> process -> next round
```

## 8. PS/PYNQ 启动流程

启动顺序必须是先 DMA，后 capture。

推荐流程：

```text
1. buf = allocate(shape=(sample_count,), dtype=np.uint32)
2. buf[:] = sentinel，例如 0xDEADBEEF
3. buf.flush()
4. dma.recvchannel.transfer(buf)
5. 配置 adc_capture AXI-Lite 参数
6. 写 CTRL start
7. dma.recvchannel.wait()
8. buf.invalidate()
9. 读取 ctrl status/debug registers
10. 拆 CH0/CH1
11. 绘图/分析/保存 CSV
```

注意：

- 必须使用 `pynq.allocate`，不要用普通 numpy array 作为 DMA buffer。
- PYNQ DMA 的 transfer 长度通常由 buffer size 推断，简单版不用显式传 nbytes。
- DMA 写 DDR 后必须 `buf.invalidate()` 再读。
- PS 端以 `dma.recvchannel.wait()` 作为 DDR 写入完成主判据。
- `CTRL.done` 只是 RTL 侧发送完成判据，不代表 DDR 已写完。
- 每次 capture 前，PS 应 clear RTL 状态，同时重新填充 sentinel 并 flush buffer。
- capture 后如果 buffer 仍有 sentinel，说明 DMA 未完整写入，或 transfer length / TLAST / AXIS_SENT_COUNT 不一致。
- 实际 DMA IP 名称以 `overlay.ip_dict.keys()` 打印结果为准。
- `ip.write(offset, value)` 使用 IP 内部 offset，不要手动加 Vivado base address。

如果 `dma.recvchannel.wait()` timeout，应读取或打印 DMA S2MM status，例如 halted、idle、DMAIntErr、DMASlvErr、DMADecErr。这样可以区分 TLAST 错误、地址错误、HP port 错误或 length 错误，而不是只靠猜。

正式比赛版本不应依赖一个个手动 notebook cell。建议后续整理成 Python 脚本或 notebook 中一个主函数：

```text
init overlay
find dma and ctrl IP
allocate buffer
configure
single-shot capture loop
analyze
display / send to STM32
```

## 9. mode 设计

保留两个主要模式：

| capture_mode | 含义 | 用途 |
|---:|---|---|
| 1 | real AD9226 | 真实 ADC 采样 |
| 2 | RTL fake stream | 不接 ADC 时验证 capture -> AXIS FIFO -> DMA -> DDR |

`capture_mode=0` 是旧 HLS writer fake 模式，不用于 AXI DMA 测试。DMA 版 Notebook
必须只使用 `capture_mode=2` 或 `capture_mode=1`。如果 DMA 已经启动后再用
`capture_mode=0` 启动 capture，RTL 不会输出 AXI-Stream/TLAST，`dma.recvchannel.wait()`
会卡住或超时。

### mode 2 fake pattern

mode 2 建议固定生成以下 pattern，方便 Python assert：

```text
idx = axis_sent_count & 0x0FFF
CH0 = idx
CH1 = 4095 - idx
packed = {4'b0000, CH1, 4'b0000, CH0}
```

Python 可检查：

```text
ch0 == (np.arange(sample_count) & 0x0FFF)
ch1 == (4095 - (np.arange(sample_count) & 0x0FFF))
```

至少检查前若干点、最后一个点，以及：

```text
LAST_AXIS_WORD == 第 sample_count-1 个 fake word
TLAST_COUNT == 1
AXIS_SENT_COUNT == sample_count
```

### channel_mask 规则

第一版 DMA packed word 永远是 32-bit 双通道格式，不因 `CHANNEL_MASK` 改变 DMA word 宽度或传输长度。

| channel_mask | CH0 field | CH1 field |
|---:|---|---|
| `0b01` | A | 0 |
| `0b10` | 0 | B |
| `0b11` | A | B |
| `0b00` | 置 config_error，建议按 `0b11` 处理 |

`SAMPLE_COUNT` 始终表示 packed word 数。

## 10. 测试计划

每阶段都必须检查：

- `dma.recvchannel.wait()` 是否返回。
- `AXIS_SENT_COUNT == SAMPLE_COUNT`。
- `TLAST_COUNT == 1`。
- `LAST_AXIS_WORD` 是否合理。
- `DROPPED_SAMPLE_COUNT == 0`。
- `AXIS_STALL_COUNT` 作为性能指标；严格连续保存测试可要求它为 0。
- buffer 中没有 sentinel 残留。
- CH1 Vpp 是否正常。
- 是否有 timeout / overflow / dropped_sample。

### 阶段 A：mode 2 fake -> DMA -> DDR

目标：不接 ADC，验证 RTL fake stream 到 DMA DDR 的完整链路。

参数：

- `capture_mode=2`
- `sample_count=1024`
- 之后测试 `16384`、`65536`

PASS 条件：

- DMA wait 返回。
- `AXIS_SENT_COUNT == sample_count`。
- `TLAST_COUNT == 1`。
- `LAST_AXIS_WORD` 等于最后一个 fake word。
- Python 拆包 CH0/CH1 符合 fake pattern。
- buffer 无 sentinel 残留。

### 阶段 B：PA5 方波，hp=12，decimation=1

目标：低采样率确认真实 ADC + DMA 链路稳定。

参数：

- `capture_mode=1`
- `adc_half_period=12`
- `decimation=1`
- Fs = 1.302MSPS

PASS 条件：

- DMA wait 返回。
- `AXIS_SENT_COUNT == sample_count`。
- `TLAST_COUNT == 1`。
- `AXIS_STALL_COUNT == 0`。
- CH1 Vpp 正常。
- 无 timeout / overflow。

### 阶段 C：PA5 方波，hp=6，decimation=1

目标：覆盖当前 HLS writer 已经能 PASS 的保存率。

参数：

- `capture_mode=1`
- `adc_half_period=6`
- `decimation=1`
- Fs = 2.604MSPS

检查同阶段 B。

### 阶段 D：PA5 方波，hp=3，decimation=1

目标：重点验证 AXI DMA 是否突破 HLS writer 瓶颈。

参数：

- `capture_mode=1`
- `adc_half_period=3`
- `decimation=1`
- Fs = 5.208MSPS

PASS 条件：

- DMA wait 返回。
- `AXIS_SENT_COUNT == sample_count`。
- `TLAST_COUNT == 1`。
- `AXIS_STALL_COUNT == 0`。
- `FIFO_BACKPRESSURE_SEEN == 0`。
- CH1 Vpp 正常。
- 无 timeout / overflow / dropped_sample。

### 阶段 E：PA5 方波，hp=1，decimation=1

目标：挑战当前 31.25MHz PL clock 下最高完整保存率。

参数：

- `capture_mode=1`
- `adc_half_period=1`
- `decimation=1`
- Fs = 15.625MSPS

严格 PASS 条件：

1. DMA wait 返回。
2. `AXIS_SENT_COUNT == sample_count`。
3. `TLAST_COUNT == 1`。
4. `DROPPED_SAMPLE_COUNT == 0`。
5. 无 axis_overflow。
6. buffer 无 sentinel 残留。
7. CH1 方波 Vpp 合理。
8. `AXIS_STALL_COUNT` 可作为性能指标；若为 0，说明仍有较好吞吐余量。

说明：如果出现 stall 但无丢点，DMA 传输仍可视为完整，但系统已经接近吞吐边界；如果目标是严格连续无停顿保存，可额外要求 `AXIS_STALL_COUNT == 0`。

### 阶段 F：hp=1，decimation=8 高速抽取对照

目标：对照旧 HLS writer 可运行条件，确认 DMA 版抽取模式稳定。

参数：

- `capture_mode=1`
- `adc_half_period=1`
- `decimation=8`
- ADC Fs = 15.625MSPS
- 有效保存率 = 1.953MSPS

检查：

- DMA wait 返回。
- `AXIS_SENT_COUNT == sample_count`。
- `TLAST_COUNT == 1`。
- CH1 Vpp 正常。
- 无 timeout / overflow。

## 11. 预期收益

当前 PL FCLK 为 31.25MHz。

当 `adc_half_period=1`：

```text
ADC Fs = 31.25MHz / (2 * 1) = 15.625MSPS
```

每个双通道采样点 packed 成一个 `uint32`：

```text
bytes_per_sample = 4
bandwidth = 15.625MSPS * 4 bytes = 62.5MB/s
```

对于 Zynq-7020 HP port + AXI DMA S2MM，62.5MB/s 是合理目标，但不是保证。实际能否 PASS 还取决于：

- DMA BD 配置。
- HP0 时钟和互联。
- DDR 仲裁。
- AXIS FIFO 深度。
- PYNQ buffer/cache 使用是否正确。
- RTL 是否能在无 stall 条件下持续送数。

如果第一版能让 `hp=3, decimation=1` 明显稳定，也已经证明 DMA 优化有效。`hp=1, decimation=1` 是努力目标。

## 12. 风险和注意事项

必须注意：

1. `TLAST` 不正确会导致 `dma.recvchannel.wait()` 卡住。
2. DMA 必须先启动，capture 后启动。
3. `SAMPLE_COUNT` 和 DMA buffer 长度必须一致。
4. DMA 传输字节数必须是 `SAMPLE_COUNT * 4`。
5. AXI-Stream backpressure 时不能改变当前待发送 word。
6. 如果没有足够前级缓存，长 backpressure 会破坏真实 ADC 的连续完整保存。
7. 如果 `AXIS_SENT_COUNT < SAMPLE_COUNT`，优先检查 tready/backpressure/状态机。
8. 如果 `TLAST_COUNT != 1`，优先检查最后一个样本的 TLAST 生成逻辑。
9. 不要改 AD9226 XDC 管脚。
10. 不要一开始提高 FCLK，先在 31.25MHz 下验证。
11. 不要一开始引入 Scatter Gather。
12. 不要一开始做硬件 continuous DMA。
13. 不要把 PS/Jupyter 当作硬实时示波器。
14. Notebook 可用于调试，比赛自动运行应整理成脚本或主函数。
15. DMA 改造不应破坏已验证的 ADC 输入时序、ODDR clock 输出方式、sample_delay 和数据打拍。
16. `ad9226_capture_axis` 应沿用已验证的 `sample_delay` 和 ADC 数据寄存方式，避免在 AXI-Stream 改造中顺手重写 ADC 采样前端。

关于 FIFO：

- AXIS Data FIFO 不是完整波形缓存。
- 完整波形在 DDR。
- FIFO 只吸收短时 DMA backpressure。
- 如果 FIFO 长时间 full，说明 DDR/DMA 路径仍跟不上。

关于 continuous：

- 第一版不是硬件 continuous streaming。
- 第一版必须支持 PS 连续多次 single-shot capture。
- 比赛准实时显示可由 PS 循环触发 single-shot 实现。

## 13. 第一版交付物

本设计路线第一版需要的交付物：

| 文件/内容 | 说明 |
|---|---|
| `docs/AD9226_AXI_DMA_CAPTURE_PLAN.md` | 本文档 |
| `ad9226_capture_axis.v` 设计说明 | RTL capture 输出 AXI-Stream，含 TREADY/TLAST/TKEEP/backpressure 规则 |
| Vivado BD 修改说明 | 增加 AXI DMA S2MM 和 AXIS Data FIFO，连接 HP0 和 GP0 |
| PYNQ DMA 测试 notebook 说明 | allocate `np.uint32` buffer，启动 DMA，启动 capture，wait，拆包画图 |

本次只完成 Markdown 设计文档，不写代码。

后续实现建议顺序：

1. 先实现 `capture_mode=2` fake stream 到 AXI DMA。
2. 验证 TLAST、TKEEP、buffer 结尾和 fake pattern。
3. 再接真实 AD9226 `capture_mode=1`。
4. 先测 hp=12、hp=6。
5. 再测 hp=3。
6. 最后挑战 hp=1、decimation=1。
