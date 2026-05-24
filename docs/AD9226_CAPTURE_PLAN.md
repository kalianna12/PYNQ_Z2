# AD9226 Dual-Channel Capture Plan

> Legacy note: this document describes the earlier HLS-writer capture route.
> The current DMA route is documented in `docs/AD9226_AXI_DMA_CAPTURE_PLAN.md`.
> Do not treat the ODDR-fast notes or `base_add_0` writer notes below as the
> current implementation status.

目标：第一版 PL 尽量一次烧录完成，后续主要在 PS/Jupyter 端通过 AXI-Lite 裸地址调采样参数、采样率、模式、LED、触发和 buffer，不频繁重新综合 PL。

主线保持：

```text
PS/Jupyter
  -> AXI-Lite bare address registers
  -> adc_ctrl_axi
  -> ad9226_capture_core
  -> adc_sample_fifo
  -> adc_writer HLS m_axi writer
  -> DDR buffer
  -> PS numpy / matplotlib / CSV / analysis
```

第一版不在 PL 做 DFT、FFT、相位、增益、RMS、滤波、mV 换算、CORDIC、同步检波等复杂计算。

## 1. Overall Architecture

```text
PYNQ PS / Jupyter
  |
  | AXI-Lite bare offset write/read
  v
adc_ctrl_axi
  | config/status/debug
  | enable/start/clear/mode/trigger/LED
  v
ad9226_capture_core
  | generates adc_a_clk / adc_b_clk from 125 MHz
  | samples AD9226 data_a/data_b
  | latest sample/debug/status
  v
adc_sample_fifo
  | packs sample_word
  | short elastic buffer, not waveform storage
  v
adc_writer HLS
  | capture_mode = 0: writer fake ramp/triangle to DDR
  | capture_mode = 1: real sample_word stream/FIFO to DDR
  | capture_mode = 2: capture_core fake stream -> FIFO -> writer -> DDR
  | m_axi_GMEM writes DDR
  v
DDR buffer allocated by PS
  |
  v
PS numpy / matplotlib / CSV / analysis
```

真实数据路径：

```text
AD9226 data_a/data_b -> RTL capture -> FIFO/stream -> HLS m_axi writer -> DDR -> PS numpy
```

fake 数据路径：

```text
capture_mode=0 -> HLS writer fake generator -> DDR -> PS numpy
capture_mode=2 -> capture_core fake stream -> FIFO/stream -> HLS writer -> DDR -> PS numpy
```

## 2. Buffer Size And Sample Count

第一版把每通道最大采样点数设为 65536：

```text
MAX_SAMPLE_N = 65536
BUFFER_WORDS = 2 * MAX_SAMPLE_N = 131072
DDR buffer bytes = 131072 * 4 = 524288 bytes = 512 KB
```

含义：

```text
buffer[0 ... sample_count-1] = CH0
buffer[MAX_SAMPLE_N ... MAX_SAMPLE_N+sample_count-1] = CH1
```

`sample_count` 是 PS 运行时可调参数：

```text
valid range: 1 ... 65536
1024 is only quick-test default, not hardware maximum
for real 10 MHz sine tests, use 16384 / 32768 / 65536
```

PS 端必须 clamp：

```python
MAX_SAMPLE_N = 65536
sample_count = min(max(sample_count, 1), MAX_SAMPLE_N)
```

PL/HLS 端也必须保护：

```text
if sample_count > MAX_SAMPLE_N:
    use MAX_SAMPLE_N
    set config_error
```

HLS writer 头文件建议：

```c
#define MAX_SAMPLE_N 65536
#define BUFFER_WORDS 131072
```

Vivado HLS 2018.2 的 pragma depth 建议写明确数字，不要在 depth 里写宏表达式：

```c
#pragma HLS INTERFACE m_axi port=buffer offset=slave bundle=GMEM depth=131072
```

## 3. Files To Add

正式命名建议：

```text
HLS top function : adc_writer
HLS files        : hls/src/adc_writer.cpp, hls/src/adc_writer.h
HLS testbench    : hls/tb/test_adc_writer.cpp
Vivado IP name   : adc_writer
BD instance      : adc_writer_0
```

过渡期说明：

```text
当前工程脚本可能仍使用 base_add_0。
过渡期可以保持 HLS IP 实例名 base_add_0，但功能实际按 adc_writer 设计。
Notebook 中 writer = overlay.base_add_0 或 overlay.adc_writer_0，以实际 hwh 为准。
稳定后再统一重构命名。
```

需要新增/修改的文件：

```text
rtl/src/adc_ctrl_axi.v
rtl/src/ad9226_capture_core.v
rtl/src/adc_sample_fifo.v

rtl/tb/tb_adc_ctrl_axi.v
rtl/tb/tb_ad9226_capture_core.v
rtl/tb/tb_adc_sample_fifo.v
rtl/tb/tb_adc_capture_chain.v

hls/src/adc_writer.cpp
hls/src/adc_writer.h
hls/tb/test_adc_writer.cpp

constraints/ad9226_pins.xdc
pynq/ad9226_capture_demo.ipynb
docs/AD9226_CAPTURE_PLAN.md
vivado/build.tcl
```

Vivado 集成目标：

```text
PS M_AXI_GP0 -> adc_ctrl_axi/S_AXI
PS M_AXI_GP0 -> adc_writer_0/s_axi_CTRL
adc_writer_0/m_axi_GMEM -> PS S_AXI_HP0
ad9226_capture_core -> adc_sample_fifo -> adc_writer_0 stream/FIFO input
ad9226_capture_core adc_a_clk/adc_b_clk -> external ADC clock pins
AD9226 data pins -> ad9226_capture_core
LED pins -> adc_ctrl_axi / status LED mux
```

## 4. Module Responsibilities

### adc_ctrl_axi.v

Side: PL RTL.

Purpose:

```text
AXI-Lite register bank
PS writes all capture parameters
PS reads status/debug registers
PS controls LED override
No algorithm work
```

Config outputs:

```text
enable, start pulse, clear pulse, soft_reset
sample_count, adc_half_period, sample_delay, decimation
channel_mask, capture_mode, trigger_mode, pre_delay
continuous_reserved, buffer_select_reserved
led_ctrl
```

Status/debug inputs:

```text
busy, done, adc_clk_seen
fifo_full, fifo_empty, fifo_overflow
near_rail_a/b or overrange_a/b depending on hardware pins
data_changed_a/b
latest_a/b, sample_counter, fifo_level, error_flags
optional writer_busy/writer_done only if connected back from writer
```

AXI needed: AXI-Lite slave.

Configuration latch rule:

```text
PS-written registers are *_cfg values.
On a valid start edge, capture_core clamps and latches *_cfg into *_run values.
The active capture uses only *_run.
If PS writes cfg registers while busy=1, those writes affect only the next capture.
```

ADC clock output mode is also fixed for one capture:

```text
Do not dynamically switch between ODDR fast path and divided path while busy=1.
adc_half_period_run is locked on start.
If PS wants to change from adc_half_period=6 to adc_half_period=1:
  1. stop/clear or soft_reset
  2. write new adc_half_period_cfg
  3. start a new capture
```

Latch on start:

```text
sample_count_run
adc_half_period_run
sample_delay_run
decimation_run
channel_mask_run
capture_mode_run
trigger_mode_run
pre_delay_run
buffer_select_run
```

Clamp on start:

```text
sample_count_cfg < 1           -> sample_count_run = 1, set config_error
sample_count_cfg > MAX_SAMPLE_N -> sample_count_run = MAX_SAMPLE_N, set config_error
adc_half_period_cfg < 1        -> adc_half_period_run = 1, set config_error
decimation_cfg < 1             -> decimation_run = 1, set config_error
sample_delay_cfg > SAMPLE_DELAY_MAX -> sample_delay_run = SAMPLE_DELAY_MAX, set config_error
```

Illegal parameters must not directly enter the sampling state machine.

### ad9226_capture_core.v

Side: PL RTL.

Purpose:

```text
Generate ADC sample clock from 125 MHz
Sample AD9226 data_a/data_b
Apply sample_delay, decimation, pre_delay, sample_count
Generate sample_valid/sample_a/sample_b
Maintain latest/debug/status registers
```

Default clock:

```text
ADC_HALF_PERIOD = 6
Fs_adc = 125_000_000 / (2 * 6) = 10.4167 MHz
```

ADC pins:

```text
input  [11:0] adc_a_data
input  [11:0] adc_b_data
output        adc_a_clk
output        adc_b_clk
```

Sample output:

```text
output        sample_valid
output [11:0] sample_a
output [11:0] sample_b
```

Debug/status:

```text
latest_a/latest_b
sample_counter
saved_counter
adc_clk_seen
data_changed_a/b
near_rail_a/b or overrange_a/b
last_sample_word
busy/done
```

Notes:

```text
ADC input first passes 1~2 register stages.
No complex combinational logic on sample path.
First version uses 125 MHz single clock domain.
First version includes an ODDR-compatible ADC_CLK output structure.
Default high-speed path uses ODDR for adc_half_period=1.
```

ADC clock behavior:

```text
CTRL.enable = 0:
  adc_a_clk / adc_b_clk stop and hold low

CTRL.enable = 1:
  adc_a_clk / adc_b_clk toggle according to ADC_HALF_PERIOD

CTRL.start rising edge:
  begin one single-shot save-to-FIFO capture
```

This lets PS first enable only the ADC clock and observe it, then decide when to
start saving samples.

ADC_CLK output strategy:

```text
First version should be ODDR-compatible.
Default preference: use ODDR for adc_half_period_run = 1.

When adc_half_period_run = 1:
  ODDR.C  = clk_125m
  ODDR.D1 = 1
  ODDR.D2 = 0
  ADC_CLK = 62.5 MHz

When adc_half_period_run > 1:
  generate adc_clk_div_r in clk_125m domain
  output divided ADC clock through a registered/OBUF path

Fs_adc = 125_000_000 / (2 * adc_half_period_run)
```

Recommended structure:

```text
adc_clk_div_r       : divided clock register for adc_half_period_run > 1
adc_clk_fast_oddr   : ODDR 62.5 MHz output for adc_half_period_run = 1
adc_clk_out_mux     : selects fast ODDR path or divided path only in a safe way
adc_a_clk           : adc_clk_out
adc_b_clk           : adc_clk_out
```

Important clock-output rule:

```text
Do not put a glitch-prone combinational mux directly on a high-speed clock
output if the selected ODDR primitive Q cannot be safely muxed with a divided
register output.

Prefer one of these:
1. Use a generate/parameterized output path for the selected implementation.
2. Use a single safe registered output path for divided mode.
3. Use ODDR fast output when adc_half_period_run == 1 and USE_ODDR_FAST == 1.

Suggested parameter:
USE_ODDR_FAST = 1
```

First version:

```text
adc_a_clk and adc_b_clk are same source, same frequency, same phase.
If the AD9226 board uses one shared clock, both output ports can drive the same
adc_clk_out.
adc_clk_out is only an external sampling clock for AD9226.
It is not an internal FPGA logic clock.
```

Single internal clock-domain rule:

```text
All first-version capture/control/FIFO logic runs in clk_125m.
Do not write always @(posedge adc_clk_out) in the first version.
Use always @(posedge clk_125m) and latch ADC data only when sample_point_pulse is 1.
```

ADC input register rule:

```verilog
always @(posedge clk_125m) begin
    adc_a_d0 <= adc_a_data;
    adc_a_d1 <= adc_a_d0;
    adc_b_d0 <= adc_b_data;
    adc_b_d1 <= adc_b_d0;
end
```

Use only `adc_a_d1` and `adc_b_d1` for latest samples, FIFO writes,
sample_word packing, and AXI-readable status. Do not feed external
`adc_a_data/adc_b_data` directly into FIFO, sample_word, or status registers.
If later high-speed capture needs tighter IO timing, consider IOB input
registers, but keep the first RTL version clear.

sample_point_pulse rule:

```text
sample_delay unit = clk_125m cycle
1 tick = 8 ns
default sample_delay = 1
recommended range = 0..31

After start, the ADC clock phase generator also starts a sample_delay counter.
When sample_delay_run is reached, generate a one-clk_125m-cycle
sample_point_pulse.
sample_point_pulse latches adc_a_d1 / adc_b_d1.

At adc_half_period_run = 1, ADC_CLK period is only 16 ns.
sample_delay that is too large can cross into the next ADC period.
For 62.5 MHz, start with sample_delay = 0 or 1 and tune by measurement.
```

### adc_sample_fifo.v

Side: PL RTL.

Purpose:

```text
Accept sample_valid/sample_a/sample_b
Pack 32-bit sample_word
Short-term decoupling between capture_core and HLS writer
Expose FIFO status
```

Sample format:

```text
bits[11:0]   = sample_a
bits[15:12]  = flags_a
bits[27:16]  = sample_b
bits[31:28]  = flags_b
```

First-version flags:

```text
flags_a[0] = near_rail_a or overrange_a
flags_a[1] = data_changed_a
flags_a[2] = reserved
flags_a[3] = reserved

flags_b[0] = near_rail_b or overrange_b
flags_b[1] = data_changed_b
flags_b[2] = reserved
flags_b[3] = reserved
```

Packing rule:

```verilog
sample_word <= {flags_b, sample_b, flags_a, sample_a};
```

`sample_word` packing must only concatenate registered fields. Do not put
division, multiplication, mV conversion, code centering, or complex comparisons
on the sample_word path.

FIFO rule:

```text
FIFO_DEPTH = 4096 recommended for first version
FIFO_DATA_WIDTH = 32
FIFO is not complete waveform storage
Do not make FIFO 65536 deep
Complete waveform is stored in DDR, not FIFO
```

Why FIFO exists:

```text
It only absorbs short writer stalls/backpressure.
If FIFO overflows, set fifo_overflow and ERROR_FLAGS[0].
First version uses synchronous FIFO because capture/FIFO/writer stream should
stay in 125 MHz domain.
If a later design crosses clock domains, replace with async FIFO or AXI-Stream FIFO IP.
```

Backpressure behavior:

```text
wr_en = sample_valid && !fifo_full

If FIFO is full and sample_valid arrives:
  do not stop ADC clock
  drop that sample
  latch fifo_overflow
  set ERROR_FLAGS[0]
  continue sampling

ADC_CLK output is controlled only by enable/soft_reset.
FIFO full must not automatically stop ADC_CLK.
High-speed capture logic may use fifo_full/fifo_empty.
fifo_level is for PS debug and must not be used in fast sampling decisions.
```

The ADC clock is a real hardware output and should not be paused just because
DDR writing is temporarily behind.

Interfaces:

```text
input sample_valid
input [11:0] sample_a
input [11:0] sample_b
output [31:0] sample_word
output sample_word_valid
input sample_word_ready
output fifo_level
output full/empty/overflow/underflow
```

Implementation choice:

```text
Prefer Vivado FIFO Generator, XPM FIFO, or a small clear synchronous FIFO.
Avoid hand-writing a complicated large FIFO in the first version.
Keep capture_core, FIFO, and writer stream in clk_125m where possible.
If a future version crosses clock domains, replace this with async FIFO or
AXI-Stream FIFO IP.
```

### adc_writer HLS

Side: PL HLS.

Purpose:

```text
Reuse verified m_axi DDR write flow.
PS writes buffer physical address and sample_count.
capture_mode=0 writes fake ramp/triangle.
capture_mode=1 reads real sample_word stream/FIFO and writes DDR.
```

Performance rules:

```text
HLS writer does not do algorithms.
It only:
  1. generates simple fake ramp/triangle in fake mode
  2. reads sample_word from stream/FIFO in real mode
  3. splits A/B raw codes
  4. writes DDR buffer

Main loop should target PIPELINE II=1.
No floating point.
No division.
No complex if-else tree.
```

Real-mode empty FIFO behavior:

```text
adc_writer may wait for stream/FIFO data.
If capture never starts or FIFO remains empty, PS timeout handles it.
Do not add complex timeout logic inside first-version HLS writer.
```

DDR buffer layout:

```text
buffer[0 ... N-1]                         = CH0
buffer[MAX_SAMPLE_N ... MAX_SAMPLE_N+N-1] = CH1
```

Layout tradeoff:

```text
Segmented layout is easy for PS slicing:
  ch0 = buf[0:sample_count]
  ch1 = buf[MAX_SAMPLE_N:MAX_SAMPLE_N+sample_count]

But each sample_word causes two writes to distant DDR addresses, so AXI burst
efficiency may be worse than interleaved layout.
If high-rate real capture cannot keep up, second-version options are:
  1. interleaved layout: buffer[2*i] = CH0, buffer[2*i+1] = CH1
  2. HLS m_axi burst optimization
  3. larger FIFO
  4. AXI DMA
```

Important:

```text
MAX_SAMPLE_N = 65536
BUFFER_WORDS = 131072
m_axi depth = 131072
```

DDR data type:

```text
DDR buffer uses int32 words.
Stored ADC values are unsigned raw codes in range 0..4095.
PL does not center, sign-convert, invert, or convert to volts.
PS interprets code format later.
```

AD9226 code-format TODO:

```text
Confirm whether the specific AD9226 module outputs offset-binary, straight
binary, inverted data, or board-specific bit order.
First-version PL stores raw code only.
PS handles interpretation and any conversion.
```

Interfaces:

```text
s_axilite CTRL
m_axi_GMEM to PS DDR through S_AXI_HP0
AXI-Stream style sample_word input for real/capture_core-fake modes
  sample_word_tdata[31:0]
  sample_word_tvalid
  sample_word_tready
```

First-version stream convention:

```text
adc_sample_fifo exposes a valid/ready/data output.
adc_writer consumes it as AXI-Stream style data.
HLS implementation should use hls::stream<ap_uint<32>> or an AXI-Stream port.
Even if the internal FIFO is simple RTL, its writer-facing exit should be
valid/ready/data to avoid redesigning this boundary later.
```

No PL algorithms:

```text
No mV conversion
No RMS
No FFT/DFT
No phase/gain
No filter
```

### system_top / Vivado BD / build.tcl

Purpose:

```text
Create processing_system7
Enable M_AXI_GP0 and S_AXI_HP0
Connect adc_ctrl_axi to M_AXI_GP0
Connect adc_writer_0 CTRL to M_AXI_GP0
Connect adc_writer_0 m_axi_GMEM to S_AXI_HP0
Connect RTL capture/FIFO/writer stream path
Connect ADC external pins and LED pins
Export bit/hwh for PYNQ
```

XDC rule:

```text
Top-level port names must match constraints/ad9226_pins.xdc get_ports names.
If a top port name changes, update XDC in the same edit.
Otherwise synthesis/implementation may fail or pins may be unconstrained.
Prefer keeping verified XDC port names stable.
```

## 5. AXI-Lite Register Table

Base address is assigned by Vivado. Final notebook constants must be corrected from:

```text
Vivado address report / vivado.log
pynq/base_add.hwh or future system.hwh
overlay.ip_dict
HLS generated xadc_writer_hw.h / xbase_add_hw.h
```

Offsets below are planned offsets inside `adc_ctrl_axi`.

| Offset | Name | R/W | Meaning |
|---:|---|---|---|
| 0x00 | CTRL | RW | control bits |
| 0x04 | STATUS | RO | status bits |
| 0x08 | SAMPLE_COUNT | RW | saved sample count, valid 1..65536 |
| 0x0C | ADC_HALF_PERIOD | RW | ADC clock half period in 125 MHz cycles |
| 0x10 | SAMPLE_DELAY | RW | delay cycles after ADC clock edge before sampling |
| 0x14 | DECIMATION | RW | save 1 sample per N ADC samples |
| 0x18 | CHANNEL_MASK | RW | bit0=A, bit1=B |
| 0x1C | CAPTURE_MODE | RW | 0=writer fake, 1=real AD9226, 2=capture_core fake stream |
| 0x20 | TRIGGER_MODE | RW | 0=software, 1=external reserved, 2=threshold reserved |
| 0x24 | PRE_DELAY | RW | delay samples after start before saving |
| 0x28 | BUFFER_SELECT | RW | reserved in first version; PS changes buffer by passing a different physical address |
| 0x2C | LATEST_A | RO | latest raw A sample |
| 0x30 | LATEST_B | RO | latest raw B sample |
| 0x34 | SAMPLE_COUNTER | RO | raw ADC sample counter |
| 0x38 | FIFO_LEVEL | RO | FIFO level |
| 0x3C | ERROR_FLAGS | RW1C | write 1 to clear error bits |
| 0x40 | LED_CTRL | RW | PS LED override/control |
| 0x44 | VERSION | RO | fixed version, e.g. 0x00010000 |
| 0x48 | SAVED_COUNTER | RO | sample_valid / FIFO-written sample count |
| 0x4C | LAST_SAMPLE_WORD | RO | latest 32-bit packed FIFO input word |
| 0x50 | DEBUG_STATE | RO | capture_core state code |

CTRL at 0x00:

| Bit | Name | Meaning |
|---:|---|---|
| 0 | enable | enable capture logic |
| 1 | start | software start pulse, detected on 0->1 edge |
| 2 | clear | write-1 pulse to clear counters/status/FIFO/errors |
| 3 | reserved | do not use; fake/real is controlled only by CAPTURE_MODE |
| 4 | continuous | reserved in first version; single-shot only |
| 5 | reserved | do not use; PS starts writer through writer AP_CTRL |
| 6 | soft_reset | soft reset internal logic |
| 7 | reserved | reserved |

Do not implement `fake_mode` in CTRL for the first version. Use only
`CAPTURE_MODE` at 0x1C. This avoids conflicts such as CTRL.fake_mode=1 while
CAPTURE_MODE=1.

Do not implement `writer_start` in adc_ctrl_axi for the first version. PS starts
the HLS writer directly:

```python
writer.write(WRITER_AP_CTRL, 0x01)
```

CAPTURE_MODE meanings:

```text
0 = writer fake mode
    HLS writer generates simple ramp/triangle by itself.
    Verifies writer -> DDR -> PS.

1 = real AD9226 mode
    AD9226 pins -> capture_core -> FIFO/stream -> writer -> DDR.

2 = capture_core fake stream mode
    capture_core generates fake sample_valid/sample_a/sample_b.
    Data still flows through FIFO/stream -> writer -> DDR.
    Verifies capture_core/FIFO/writer without real ADC wiring.
```

Debug interpretation:

```text
mode 0 works, mode 2 works, mode 1 fails -> focus on AD9226 wiring,
sample edge, bit order, or analog input.
mode 0 works, mode 2 fails -> focus on capture_core/FIFO/stream link.
mode 0 fails -> focus on writer/DDR/PS buffer flow first.
```

CHANNEL_MASK rule:

```text
DDR layout never changes.

channel_mask = 0b01:
  CH0 = A
  CH1 = 0

channel_mask = 0b10:
  CH0 = 0
  CH1 = B

channel_mask = 0b11:
  CH0 = A
  CH1 = B

channel_mask = 0b00:
  set config_error
  clamp to 0b11 so writer still receives valid data
```

Control bit semantics:

```text
enable:
  level bit
  0 = ADC clock held low and capture idle
  1 = ADC clock runs according to ADC_HALF_PERIOD

start:
  software start pulse
  capture_core detects 0 -> 1 edge
  first version is single-shot capture only

clear:
  write-1 pulse
  clears counters, done/busy state, FIFO state, and latched errors
  PS should release it by writing CTRL without bit2 set

continuous:
  reserved in first version
  do not implement continuous capture yet
```

Recommended PS start sequence:

```python
ctrl.write(CTRL, 0x04)  # clear pulse
ctrl.write(CTRL, 0x00)  # release clear
ctrl.write(CTRL, 0x01)  # enable, ADC clock runs
ctrl.write(CTRL, 0x03)  # enable + start pulse
ctrl.write(CTRL, 0x01)  # release start, keep enable
```

Single-shot only:

```text
First version only supports one capture per start edge.
continuous bit is reserved because continuous mode creates extra questions:
buffer overwrite, writer restart, done behavior, and stream draining.
```

BUFFER_SELECT:

```text
BUFFER_SELECT is reserved in first version.
It does not affect hardware logic yet.
Double buffering can be done by PS passing a different physical_address to the
writer, or by a later hardware buffer_select design.
```

STATUS at 0x04:

| Bit | Name | Meaning |
|---:|---|---|
| 0 | busy | capture busy |
| 1 | done | capture_core has produced sample_count valid saved samples |
| 2 | adc_clk_seen | ADC clock toggled |
| 3 | fifo_full | FIFO full |
| 4 | fifo_empty | FIFO empty |
| 5 | fifo_overflow | FIFO overflow |
| 6 | near_rail_a | A raw code near 0 or 4095, unless ORA pin is connected |
| 7 | near_rail_b | B raw code near 0 or 4095, unless ORB pin is connected |
| 8 | reserved | writer_busy only if explicitly connected back |
| 9 | reserved | writer_done only if explicitly connected back |
| 10 | error | any error |
| 11 | data_changed_a | A channel changed |
| 12 | data_changed_b | B channel changed |

Writer status rule:

```text
First version can avoid merging writer_busy/writer_done into adc_ctrl_axi.STATUS.
PS should read both:
  ctrl_status = ctrl.read(0x04)
  writer_ctrl = writer.read(0x00)
If STATUS bit8/bit9 are kept, Vivado BD/RTL must connect writer status back.
If not connected, bit8/bit9 are reserved/always 0.
```

Important:

```text
STATUS.done only means capture_core is done producing saved samples.
It does not mean DDR write is finished.
DDR completion must be checked with writer AP_CTRL.ap_done.
```

Near rail vs hardware overrange:

```text
If XDC/top truly connects AD9226 ORA/ORB pins, use names overrange_a/b.
If not, and logic only checks raw code near 0 or 4095, use near_rail_a/b.
Do not call near-rail detection hardware overrange.
First version assumes near_rail_a/b unless ORA/ORB pins are explicitly added.
```

ERROR_FLAGS at 0x3C:

| Bit | Name |
|---:|---|
| 0 | fifo_overflow |
| 1 | fifo_underflow |
| 2 | adc_near_rail_a or adc_overrange_a if ORA connected |
| 3 | adc_near_rail_b or adc_overrange_b if ORB connected |
| 4 | writer_timeout |
| 5 | config_error |

`writer_timeout` is reserved in the first version. Timeout is mainly handled by
PS/Jupyter polling; if the writer waits too long, PS prints STATUS,
ERROR_FLAGS, FIFO_LEVEL, and writer AP_CTRL for debug.

LED_CTRL at 0x40:

| Bit | Name | Meaning |
|---:|---|---|
| 3:0 | led_value | manual LED value |
| 8 | ps_led_override | 1=PS controls LED, 0=auto status LED |

Auto LED when override=0:

```text
leds = {error, done, busy, adc_clk_seen}
```

Debug register meanings:

```text
SAVED_COUNTER:
  valid samples written into FIFO/stream after pre_delay and decimation

LAST_SAMPLE_WORD:
  latest packed 32-bit sample_word written toward FIFO

DEBUG_STATE:
  0 = IDLE
  1 = ARMED
  2 = PRE_DELAY
  3 = CAPTURING
  4 = DONE
  5 = ERROR

VERSION:
  example 0x00010000 = v1.0.0
  update VERSION whenever register layout or interface changes
```

Writer-side debug counters are recommended:

```text
WRITER_READ_COUNTER:
  writer has consumed this many sample_word values from FIFO/stream

WRITER_WRITE_COUNTER:
  writer has written this many samples per channel into DDR
```

These can live in adc_writer AXI-Lite read-only registers. They help separate
capture/FIFO problems from writer/DDR problems.

Counter definitions:

```text
SAMPLE_COUNTER = raw ADC sampling edge counter
SAVED_COUNTER  = sample_valid / FIFO-written valid sample counter
```

`SAVED_COUNTER` is strongly recommended in the first version. It answers the
debug question: ADC clock is running, but after pre_delay/decimation, how many
samples were actually saved?

`LAST_SAMPLE_WORD` at 0x4C should be included in the first version:

```text
bits[11:0]   = latest saved A
bits[15:12]  = flags_a
bits[27:16]  = latest saved B
bits[31:28]  = flags_b

flags_a[0] = near_rail_a or overrange_a
flags_a[1] = data_changed_a
flags_a[3:2] = reserved
flags_b[0] = near_rail_b or overrange_b
flags_b[1] = data_changed_b
flags_b[3:2] = reserved
```

It is cheap and very useful for PS-side debug without ILA.

Parameter limits:

```text
SAMPLE_COUNT:
  valid 1..65536
  0 -> treat as 1 and set config_error
  >65536 -> use 65536 and set config_error

ADC_HALF_PERIOD:
  valid 1..65535
  0 -> treat as 1 and set config_error

SAMPLE_DELAY:
  unit = 125 MHz cycles, 1 tick = 8 ns
  recommended first-version range 0..31
  default 1
  at high Fs, too much delay can cross into the next ADC period

DECIMATION:
  valid 1..65535
  0 -> treat as 1 and set config_error
```

Error clearing:

```text
ERROR_FLAGS is RW1C:
  write 1 to clear the corresponding bit
  write 0 leaves the bit unchanged

CTRL.clear can clear all errors and counters.
```

PS example:

```python
ctrl.write(ERROR_FLAGS, 0xFFFFFFFF)
```

HLS writer offsets:

```text
Use HLS report and xadc_writer_hw.h / xbase_add_hw.h after generation.
Do not assume addresses after adding ports.
Current verified style:
0x00 AP_CTRL
0x10 BUFFER_R_DATA
0x18 SAMPLE_COUNT_DATA
```

Writer capture_mode rule:

```text
PS must write the same capture_mode to adc_ctrl_axi and adc_writer.
```

First version decision:

```text
adc_writer must include a capture_mode AXI-Lite parameter.
Its offset is determined by the HLS report/generated header.
Before start, PS must write both:
  adc_ctrl_axi.CAPTURE_MODE
  adc_writer.CAPTURE_MODE
```

Reason: the writer must know whether to generate fake data or read real stream
data. Keeping capture_mode in writer avoids adding extra external source muxing
in BD/RTL.

## 6. Capture Mode Synchronization

Global rule:

```text
adc_ctrl_axi.CAPTURE_MODE is the global mode register.
adc_writer must also have a capture_mode AXI-Lite register.
PS must write both before start.
```

Real/capture-core-stream mode count rule:

```text
adc_ctrl_axi.SAMPLE_COUNT and adc_writer.SAMPLE_COUNT must be the same value.

capture_core target:
  SAVED_COUNTER == sample_count

writer target:
  WRITER_READ_COUNTER == sample_count
  WRITER_WRITE_COUNTER == sample_count
  DDR contains sample_count points per channel
```

If these counts do not match, the common failure is:

```text
capture_core produces 1024 samples
writer waits for 65536 samples
PS eventually sees timeout
```

Notebook pattern:

```python
ctrl.write(0x1C, capture_mode)

# If HLS writer generated this register:
writer.write(WRITER_CAPTURE_MODE, capture_mode)
```

Avoid:

```text
ctrl real + writer fake
ctrl fake + writer real
```

This mismatch is a classic confusing bug.

## 7. Jupyter Notebook Structure

Notebook can use bare offsets. Final base addresses must be corrected from `.hwh`, Vivado logs, and `overlay.ip_dict`.

PYNQ `ip.write(offset, value)` / `ip.read(offset)` uses the IP-local offset:

```python
ctrl.write(0x08, sample_count)                 # correct
ctrl.write(0x43C00000 + 0x08, sample_count)    # wrong for PYNQ IP object
```

Vivado base addresses are for checking `overlay.ip_dict` and debugging, not
for adding onto offsets when using the PYNQ IP object.

### Cell 1: Load Overlay And IPs

```python
from time import sleep, time
import numpy as np
import matplotlib.pyplot as plt
from pynq import Overlay, allocate

overlay = Overlay("base_add.bit")
print(overlay.ip_dict)

# Transition period: use actual names from hwh.
ctrl = overlay.adc_ctrl_axi_0
writer = overlay.base_add_0      # or overlay.adc_writer_0 after rename

print(ctrl)
print(writer)
print(ctrl.register_map)
print(writer.register_map)
```

### Cell 2: Parameters

```python
MAX_SAMPLE_N = 65536
BUFFER_WORDS = 2 * MAX_SAMPLE_N

sample_count = 1024   # quick verification default; real tests use 16384 / 32768 / 65536
sample_count = min(max(sample_count, 1), MAX_SAMPLE_N)

target_adc_fs = 10_000_000
adc_half_period = round(125_000_000 / (2 * target_adc_fs))
adc_half_period = max(1, adc_half_period)
actual_adc_fs = 125_000_000 / (2 * adc_half_period)

sample_delay = 1
decimation = 1
channel_mask = 0b11
capture_mode = 0       # first fake, confirm DDR/PS path; then change to 1 real AD9226
trigger_mode = 0
pre_delay = 0
buffer_select = 0
led_ps_override = 0
led_value = 0

print("target_adc_fs =", target_adc_fs)
print("adc_half_period =", adc_half_period)
print("actual_adc_fs =", actual_adc_fs)
print("sample_count =", sample_count)
```

Notes:

```text
capture_mode=0 is fake self-test.
capture_mode=1 is real AD9226.
For observing a 10 MHz sine shape, use adc_half_period=2 or 1 and at least 16384 samples.
```

### Cell 3: Write Registers, Allocate Buffer, Start

```python
CTRL          = 0x00
STATUS        = 0x04
SAMPLE_COUNT  = 0x08
ADC_HALF      = 0x0C
SAMPLE_DELAY  = 0x10
DECIMATION    = 0x14
CHANNEL_MASK  = 0x18
CAPTURE_MODE  = 0x1C
TRIGGER_MODE  = 0x20
PRE_DELAY     = 0x24
BUFFER_SELECT = 0x28
LATEST_A      = 0x2C
LATEST_B      = 0x30
SAMPLE_CNTR   = 0x34
FIFO_LEVEL    = 0x38
ERROR_FLAGS   = 0x3C
LED_CTRL      = 0x40
VERSION       = 0x44
SAVED_COUNTER = 0x48
LAST_SAMPLE   = 0x4C
DEBUG_STATE   = 0x50

# Replace writer offsets using HLS generated report/header.
WRITER_AP_CTRL = 0x00
WRITER_BUFFER  = 0x10
WRITER_COUNT   = 0x18
# WRITER_CAPTURE_MODE = ...  # if generated by HLS writer

buf = allocate(shape=(2 * MAX_SAMPLE_N,), dtype=np.int32)
buf[:] = -12345
buf.flush()

ctrl.write(CTRL, 0x04)  # clear capture/FIFO/status first
ctrl.write(CTRL, 0x00)  # release clear

sample_count = min(max(sample_count, 1), MAX_SAMPLE_N)
decimation = max(1, decimation)
adc_half_period = max(1, adc_half_period)

ctrl.write(SAMPLE_COUNT, sample_count)
ctrl.write(ADC_HALF, adc_half_period)
ctrl.write(SAMPLE_DELAY, sample_delay)
ctrl.write(DECIMATION, decimation)
ctrl.write(CHANNEL_MASK, channel_mask)
ctrl.write(CAPTURE_MODE, capture_mode)
ctrl.write(TRIGGER_MODE, trigger_mode)
ctrl.write(PRE_DELAY, pre_delay)
ctrl.write(BUFFER_SELECT, buffer_select)
ctrl.write(LED_CTRL, (led_ps_override << 8) | led_value)

writer.write(WRITER_BUFFER, buf.physical_address)
writer.write(WRITER_COUNT, sample_count)

# If the writer owns a capture_mode register, keep it synchronized:
# writer.write(WRITER_CAPTURE_MODE, capture_mode)

if capture_mode == 0:
    # Fake mode: writer can generate data; capture_core can stay disabled.
    writer.write(WRITER_AP_CTRL, 0x01)
else:
    # Real mode:
    # 1. enable capture but do not start yet
    # 2. start writer so it can wait for FIFO/stream
    # 3. start capture so sample_valid begins after writer is ready
    ctrl.write(CTRL, 0x01)            # enable
    writer.write(WRITER_AP_CTRL, 0x01)
    ctrl.write(CTRL, 0x03)            # enable + start pulse
    ctrl.write(CTRL, 0x01)            # release start, keep enable

timeout_s = 5.0
t0 = time()
while True:
    ctrl_status = ctrl.read(STATUS)
    writer_ctrl = writer.read(WRITER_AP_CTRL)
    writer_done = (writer_ctrl & 0x2) != 0
    ctrl_done = (ctrl_status & (1 << 1)) != 0

    if capture_mode == 0:
        done = writer_done
    else:
        done = writer_done and ctrl_done

    if done:
        break

    if time() - t0 > timeout_s:
        fifo_level = ctrl.read(FIFO_LEVEL)
        err = ctrl.read(ERROR_FLAGS)
        raise TimeoutError(
            "capture timeout: STATUS=0x%08X ERROR=0x%08X FIFO=%d AP_CTRL=0x%08X"
            % (ctrl_status, err, fifo_level, writer_ctrl)
        )

buf.invalidate()
```

### Cell 4: Status, Plot, CSV

```python
status = ctrl.read(STATUS)
latest_a = ctrl.read(LATEST_A)
latest_b = ctrl.read(LATEST_B)
sample_counter = ctrl.read(SAMPLE_CNTR)
fifo_level = ctrl.read(FIFO_LEVEL)
error_flags = ctrl.read(ERROR_FLAGS)
version = ctrl.read(VERSION)
saved_counter = ctrl.read(SAVED_COUNTER)
last_sample = ctrl.read(LAST_SAMPLE)
debug_state = ctrl.read(DEBUG_STATE)
writer_ctrl = writer.read(WRITER_AP_CTRL)

print("STATUS       = 0x%08X" % status)
print("WRITER_CTRL  = 0x%08X" % writer_ctrl)
print("LATEST_A     =", latest_a)
print("LATEST_B     =", latest_b)
print("SAMPLE_CNTR  =", sample_counter)
print("FIFO_LEVEL   =", fifo_level)
print("ERROR_FLAGS  = 0x%08X" % error_flags)
print("VERSION      = 0x%08X" % version)
print("SAVED_CNTR   =", saved_counter)
print("LAST_SAMPLE  = 0x%08X" % last_sample)
print("DEBUG_STATE  =", debug_state)

ch0 = np.array(buf[0:sample_count], dtype=np.int32)
ch1 = np.array(buf[MAX_SAMPLE_N:MAX_SAMPLE_N + sample_count], dtype=np.int32)

t = np.arange(sample_count) / (actual_adc_fs / decimation)

plt.figure(figsize=(12, 4))
plt.plot(t, ch0, label="CH0 raw")
plt.plot(t, ch1, label="CH1 raw")
plt.grid(True)
plt.legend()
plt.show()

ch0_centered = ch0 - np.mean(ch0)
ch1_centered = ch1 - np.mean(ch1)

plt.figure(figsize=(12, 4))
plt.plot(t, ch0_centered, label="CH0 centered")
plt.plot(t, ch1_centered, label="CH1 centered")
plt.grid(True)
plt.legend()
plt.show()

def stats(x):
    return {
        "mean": float(np.mean(x)),
        "vpp": int(np.max(x) - np.min(x)),
        "rms_centered": float(np.sqrt(np.mean((x - np.mean(x)) ** 2))),
    }

print("CH0", stats(ch0))
print("CH1", stats(ch1))

np.savetxt("ad9226_capture.csv", np.column_stack([ch0, ch1]), delimiter=",", header="ch0,ch1", comments="")
```

Jupyter display rule:

```text
First-version PS display is quasi-real-time:
  single-shot capture -> DDR -> PS invalidate/read -> matplotlib plot

Jupyter/matplotlib is not a continuous real-time oscilloscope.
For refresh, use a Python while loop that repeats single-shot capture.
Hardware continuous capture and DMA streaming are later-version topics.
```

## 8. Default Parameters

```text
MAX_SAMPLE_N    = 65536
BUFFER_WORDS    = 131072
buffer size     = 512 KB
sample_count    = 1024 quick test, then 16384 / 32768 / 65536
target_adc_fs   = 10 MHz
adc_half_period = 6
actual_adc_fs   = 10.4167 MHz
sample_delay    = 1
decimation      = 1
channel_mask    = 0b11
capture_mode    = 0 first fake, then 1 real
trigger_mode    = 0 software
pre_delay       = 0
buffer_select   = 0
FIFO_DEPTH      = 4096
```

PS clamp rules:

```python
sample_count = min(max(sample_count, 1), MAX_SAMPLE_N)
adc_half_period = max(1, adc_half_period)
decimation = max(1, decimation)
```

ADC sample rate formula:

```text
Fs_adc = 125_000_000 / (2 * ADC_HALF_PERIOD)
```

Examples:

| ADC_HALF_PERIOD | Fs |
|---:|---:|
| 7 | 8.9286 MHz |
| 6 | 10.4167 MHz |
| 5 | 12.5 MHz |
| 4 | 15.625 MHz |
| 3 | 20.833 MHz |
| 2 | 31.25 MHz |
| 1 | 62.5 MHz |

Start near 10 MHz for wiring/data/DDR path validation. Do not start at top rate.

## 9. 10 MHz Sine Wave Sampling Note

If ADC sampling rate is about 10.4167 MHz and the input sine is also 10 MHz:

```text
points per sine period = 10.4167 / 10 = about 1.04
```

That cannot reliably show a sine shape. It only proves data changes and the chain is alive.

For a visible 10 MHz sine:

```text
adc_half_period = 2 -> Fs = 31.25 MSPS -> about 3.125 points/period
adc_half_period = 1 -> Fs = 62.5 MSPS  -> about 6.25 points/period
```

Recommended path:

```text
1. Start with adc_half_period=6, confirm wiring/data/DDR.
2. Then try adc_half_period=2.
3. Then try adc_half_period=1 only after signal integrity and timing look good.
4. For adc_half_period=1, use the default ODDR fast ADC_CLK output path.
```

AD9226 is about 65 MSPS class. 125 MHz ODDR fast output gives 62.5 MSPS,
close to the top end. Do not use this as the first test.

Digital WNS PASS does not prove the external ADC wiring is reliable at
62.5 MHz. External clock/data wiring still needs real oscilloscope or
PS-visible data checks.

Analog front-end warning:

```text
Before feeding 10 MHz into AD9226, confirm input amplitude, bias/common-mode,
source impedance, coupling, and protection are correct.
Do not connect an over-range or incorrectly biased signal directly to the ADC.
At 10 MHz, analog front-end mistakes can look like digital capture bugs.
```

Real AD9226 tuning order:

```text
1. Lower ADC sampling rate first, for example adc_half_period=12 or 6.
2. Sweep sample_delay from 0, 1, 2, 3.
3. Watch latest_a/b, data_changed, near_rail, last_sample_word, and raw plot.
4. After data is stable, raise speed to adc_half_period=2.
5. Try adc_half_period=1 only after lower-speed wiring and timing are sane.
```

## 10. Throughput And Future Writer Optimization

First version should prioritize correctness over throughput tricks.

If 31.25 MSPS or 62.5 MSPS real-mode capture fails:

```text
1. Check FIFO overflow first.
2. Increase DECIMATION or lower ADC Fs from PS.
3. Confirm writer_done and AP_CTRL behavior.
4. Only later optimize HLS m_axi burst behavior, increase FIFO depth, or move to AXI DMA.
```

Do not introduce DMA in the first version.

First-version layout policy:

```text
Use segmented DDR layout first to stay compatible with current PS slicing and
the existing HLS demo style.

For 62.5 MSPS, 65536-point real capture, segmented layout may not be the final
throughput shape. If FIFO overflow appears while ADC/capture/FIFO behavior is
otherwise correct, second version should first consider interleaved DDR layout:
  buffer[2*i]   = CH0
  buffer[2*i+1] = CH1
```

## 11. One-Bitstream Goal And Realistic Boundary

The first bitstream should make these PS-adjustable:

```text
sample_count
adc_half_period
sample_delay
decimation
capture_mode
channel_mask
LED control
pre_delay
buffer_select
trigger mode reserved registers
```

But these still require re-synthesis / implementation / bitstream:

```text
XDC pin mistakes
top-level port mistakes
AXI interface mistakes
FIFO/stream wiring mistakes
HLS port changes
RTL module port changes
adding ILA
changing FIFO implementation type
adding real trigger logic beyond reserved registers
```

Debug/status registers reduce ILA dependence, but cannot guarantee zero future bitstream changes.

## 12. ILA And PS Debug

```text
PS cannot directly do ILA.
ILA is a PL debug core inserted by Vivado.
If ILA was not included before implementation, adding it usually requires
re-synthesis, re-implementation, and a new bitstream.
```

First version should expose enough PS-readable debug registers:

```text
latest_a
latest_b
sample_counter
saved_counter
adc_clk_seen
data_changed_a
data_changed_b
fifo_level
fifo_overflow
error_flags
last_sample_word
```

Only if these are not enough, make a second debug bitstream with ILA.

Second-version ILA probes:

```text
adc_clk_out
adc_a_data / adc_b_data
sample_valid
sample_a / sample_b
fifo_wr_en
fifo_level
fifo_full / fifo_empty / fifo_overflow
writer stream read/ready/valid
writer done
```

## 13. Timing / WNS / PL Performance Rules

Most likely WNS pressure points:

| Risk Area | Why It Hurts | Avoidance |
|---|---|---|
| ADC input path | external pins into logic | 1~2 register stages before use; later consider IOB input registers |
| ADC_CLK output | high-speed external clock quality | first version includes ODDR-compatible output; adc_half_period=1 uses ODDR fast path |
| sample edge logic | ADC phase, sample_delay, decimation counters | keep one clk_125m domain, generate sample_point_pulse |
| sample_word packing | can grow if flags/debug logic is added | concatenate registered signals only |
| FIFO write path | overflow/backpressure can grow logic | wr_en = sample_valid && !fifo_full |
| FIFO level/full logic | pointer comparators can grow | fast path uses full/empty only; fifo_level is PS debug only |
| AXI-Lite status mux | many status regs in one read mux | latch read address; register RDATA |
| HLS stream to DDR | backpressure and burst behavior | FIFO boundary, PS timeout, later burst/interleaved/DMA optimization |
| debug/status fanout | status used everywhere | local registered status; LED/debug use registered signals |
| near_rail logic | extra comparators on data path | optional; if in PL, only simple registered comparators |

### ADC_CLK Output Rules

```text
First version is ODDR-compatible.
Default high-speed behavior:
  adc_half_period_run = 1 and USE_ODDR_FAST = 1 -> ODDR 62.5 MHz output

ODDR fast output:
  C  = clk_125m
  D1 = 1
  D2 = 0
  Q  = adc_clk_fast_oddr

Divided output:
  adc_half_period_run > 1 -> clk_125m-domain divider creates adc_clk_div_r

adc_a_clk and adc_b_clk are same source, same frequency, same phase.
If the ADC board uses one shared clock, both output ports can drive the same adc_clk_out.
adc_clk_out is external only; do not use it as an internal FPGA clock.
```

Avoid unsafe clock muxing:

```text
Do not place a glitch-prone combinational mux directly on a high-speed clock
output if ODDR.Q cannot be safely selected against a divided register output.

Use a generate/parameterized path, or a carefully registered/safe output path.
The important rule is: no casual combinational clock mux on ADC_CLK.
```

### One Internal Clock Domain

```text
First version capture/control/FIFO logic uses clk_125m only.
Forbidden in first version:
  always @(posedge adc_clk_out)

Recommended:
  always @(posedge clk_125m) begin
      if (sample_point_pulse)
          latch registered ADC data;
  end
```

`sample_point_pulse` is generated from `adc_half_period_run`,
`sample_delay_run`, and the ADC clock phase, all inside the clk_125m domain.
This avoids CDC and keeps timing constraints simpler.

### ADC Input Registering

```verilog
always @(posedge clk_125m) begin
    adc_a_d0 <= adc_a_data;
    adc_a_d1 <= adc_a_d0;
    adc_b_d0 <= adc_b_data;
    adc_b_d1 <= adc_b_d0;
end
```

Rules:

```text
Use adc_a_d1 / adc_b_d1 for latest_a/b, sample_a/b, sample_word, and status.
Do not feed raw external adc_data directly into FIFO, packing, or AXI registers.
If high-speed testing needs better IO timing, later consider IOB input registers.
```

### sample_delay And sample_point_pulse

```text
sample_delay unit = clk_125m cycle = 8 ns
default sample_delay = 1
recommended range = 0..31

On start, the clock phase generator and delay counter run in clk_125m.
When sample_delay_run is reached, emit a one-cycle sample_point_pulse.
sample_point_pulse latches adc_a_d1 / adc_b_d1.

At adc_half_period_run = 1, ADC_CLK period is 16 ns.
Large sample_delay values can cross into the next ADC cycle.
For 62.5 MHz, start with sample_delay = 0 or 1 and tune by measurement.
```

### Shadow Config And Clamp

```text
PS-visible registers are *_cfg.
On start edge, clamp and latch them into *_run.
Active capture uses only *_run.
busy=1 PS writes affect only the next capture.
```

Clamp at start:

```text
sample_count_cfg < 1            -> 1, set config_error
sample_count_cfg > MAX_SAMPLE_N -> MAX_SAMPLE_N, set config_error
adc_half_period_cfg < 1         -> 1, set config_error
decimation_cfg < 1              -> 1, set config_error
sample_delay_cfg > SAMPLE_DELAY_MAX -> SAMPLE_DELAY_MAX, set config_error
```

### start / clear / soft_reset

```text
start:
  software pulse; capture_core detects 0 -> 1 edge

clear:
  clears counters, done, errors, FIFO status
  does not clear configuration registers
  use as write-1 pulse, then release

soft_reset:
  resets internal state machines, FIFO state, and errors more thoroughly
  can be used to abort a current capture

Before every start:
  clear FIFO/status first to avoid stale data entering the next capture
```

Recommended PS sequence:

```python
ctrl.write(CTRL, 0x04)  # clear pulse
ctrl.write(CTRL, 0x00)  # release clear
ctrl.write(CTRL, 0x01)  # enable clock/capture logic
ctrl.write(CTRL, 0x03)  # enable + start pulse
ctrl.write(CTRL, 0x01)  # release start
```

### continuous / buffer_select

```text
continuous is reserved in the first version.
First version supports only single-shot capture.
For quasi-real-time refresh, PS repeats single-shot capture in a Python loop.

BUFFER_SELECT is reserved in the first version.
Double buffering can be done by PS passing a different physical_address to
the writer, or by a later hardware buffer_select design.
```

### FIFO And Backpressure

```text
FIFO_DEPTH = 4096
FIFO_DATA_WIDTH = 32
FIFO is not waveform storage; full waveform is in DDR.
FIFO only absorbs short capture_core <-> writer rate mismatch.
```

Fast-path rule:

```text
wr_en = sample_valid && !fifo_full

if sample_valid && fifo_full:
  drop current sample
  latch fifo_overflow
  set ERROR_FLAGS[0]
  keep ADC_CLK running
```

Do not stop ADC_CLK because FIFO is full. ADC_CLK output is controlled by
enable/soft_reset, not by backpressure. High-speed logic uses `fifo_full` and
`fifo_empty`; `fifo_level` is for PS debug only.

### AXI-Lite Timing Rules

```text
Keep AXI-Lite control path separate from ADC sample path.
Latch AXI read address on read-address handshake.
Output S_AXI_RDATA from a register on the next cycle.
Do not wire dozens of live status/debug signals directly into S_AXI_RDATA.
Register status, error_flags, fifo_level, latest samples, counters, and state.
LED/debug outputs use registered status signals only.
Do not let the AXI-Lite read mux become the WNS critical path.
```

### HLS Writer Rules

```text
HLS writer moves data only.
No float, no division, no algorithms.
Pipeline the main loop toward II=1.
Real mode may wait for stream/FIFO data.
If data never arrives, PS timeout handles it; do not add complex HLS timeout.
```

First version keeps segmented layout:

```text
buffer[0 ... N-1] = CH0
buffer[MAX_SAMPLE_N ... MAX_SAMPLE_N+N-1] = CH1
```

Segmented layout is simple for PS slicing but may be less burst-friendly.
If high-rate writer throughput is insufficient, later consider interleaved
layout, better HLS burst, larger FIFO, or AXI DMA.

### XDC / Ports / External Timing

```text
Keep verified XDC port names stable.
Top-level ports must match XDC get_ports names.
If a top port name changes, update XDC in the same change.

Define bit order clearly:
  adc_a_data[0]  = A1 / LSB
  adc_a_data[11] = A12 / MSB
  adc_b_data[0]  = B1 / LSB
  adc_b_data[11] = B12 / MSB

First-version PL does not reorder bits unless XDC proves it is necessary.
First-version PL does not convert ADC code format; it stores raw code only.
AD9226 output code type, inversion, or board-specific bit order is interpreted
by PS or confirmed in a later revision.
```

External reality check:

```text
Digital WNS PASS does not prove external jumper wiring works at 62.5 MHz.
Test external ADC connection in order:
  1 MHz / 5 MHz / 10 MHz
  31.25 MHz
  62.5 MHz

Use short wiring, shared ground, and avoid long flying leads.
```

Near-rail policy:

```text
near_rail_a/b is optional.
For the most minimal first version, expose latest_a/b and let PS judge near rail.
If implemented in PL, use only simple registered comparisons against low/high
raw-code thresholds. Do not make it a wider algorithm block.
```

## 14. First-Bitstream Validation Route

### M1: Build one complete base PL

Goal:

```text
Include adc_ctrl_axi, ad9226_capture_core, adc_sample_fifo, adc_writer,
fake mode, real mode, LED override, debug/status registers.
```

Modules:

```text
adc_ctrl_axi
ad9226_capture_core
adc_sample_fifo
adc_writer HLS
Vivado BD/build.tcl
```

Verify:

```text
HLS_REPORT PASS
RTL_REPORT PASS
VIVADO_OVERLAY_REPORT PASS
WNS > 0
```

Failure points:

```text
AXI address mismatch
stream/FIFO connection mismatch
ADC pins not constrained
HLS writer offsets changed
```

### M2: PS tests fake mode

PS parameters:

```text
capture_mode = 0
sample_count = 1024 first quick test
then sample_count = 16384 / 65536
decimation = 1
```

Verify:

```text
DDR buffer contains ramp/triangle
plot shows expected fake waveform
large buffer works
no FIFO/error flags
```

Failure points:

```text
wrong writer buffer address
cache flush/invalidate missing
wrong sample_count offset
sample_count not clamped
```

### M3: PS tests LED and registers

PS parameters:

```text
LED_CTRL ps_led_override=1, led_value changes
read VERSION
read STATUS
```

Verify:

```text
LED follows PS writes
VERSION = 0x00010000
STATUS bits make sense
```

Failure points:

```text
wrong adc_ctrl_axi base address
wrong LED constraints
```

### M4: PS outputs ADC clock

PS parameters:

```text
capture_mode = 1
target_adc_fs = 10 MHz
adc_half_period = 6
sample_delay = 1
```

Verify:

```text
adc_clk_seen = 1
sample_counter increments
scope sees ~10.4167 MHz ADC clock
```

Failure points:

```text
ADC clock pin wrong
clock too fast for wiring
counter not enabled
```

### M5: PS reads latest sample

PS parameters:

```text
adjust sample_delay
adjust adc_half_period
adjust decimation
```

Verify:

```text
LATEST_A/B change when ADC input changes
data_changed_a/b = 1
near_rail flags only near raw rail codes
```

Failure points:

```text
ADC data pin order wrong
input voltage invalid
sample edge wrong
```

### M6: PS captures real waveform to DDR

PS parameters:

```text
capture_mode = 1
sample_count = 1024 first
then sample_count = 16384 / 32768 / 65536
decimation = 1 or higher
channel_mask = 0b11
```

10 MHz sine note:

```text
Use at least 16384 points.
Use adc_half_period=2 or 1 to see waveform shape.
If FIFO overflow appears, first increase decimation or lower ADC Fs.
Do not immediately change PL.
```

Verify:

```text
buffer CH0/CH1 contain raw ADC waveform
plot shows expected shape
fifo_overflow = 0
writer_done = 1
ctrl_done = 1
```

Failure points:

```text
FIFO overflow
writer timeout
wrong stream packing
wrong buffer layout
```

### M7: PS basic analysis

PS does:

```text
raw plot
centered plot
mean
Vpp
RMS
CSV save
```

Verify:

```text
values reasonable
CSV opens correctly
no PL changes needed
```

Failure points:

```text
wrong ADC code interpretation
wrong effective Fs after decimation
bad analog front-end scaling
```

### M8: Optional second debug bit with ILA

Only if PS-visible debug registers are not enough.

Add ILA probes:

```text
adc_clk_out
adc_data
sample_valid
fifo_wr_en
fifo_level
writer read/valid/ready
done/error
```

Verify in Vivado Hardware Manager after new bitstream.

## 15. Modules Not To Include In First Version

Do not connect these in the first AD9226 base bit:

```text
DFT / FFT
phase detector
gain detector
RMS calculator
mV conversion
floating-point processing
CORDIC
sync detector
sync_detector old module
adv_h0_bypass_core
SPI protocol blocks not required for AD9226 sampling
DMA
MMCM/PLL dynamic reconfiguration
threshold trigger implementation beyond reserved registers
external trigger implementation beyond reserved registers
```

Keep the first bitstream boring, visible, and stable.

## 16. First-Version Implementation Checklist

```text
[ ] XDC port names confirmed
[ ] adc_a_data[0] is LSB
[ ] adc_b_data[0] is LSB
[ ] MAX_SAMPLE_N = 65536
[ ] BUFFER_WORDS = 131072
[ ] FIFO_DEPTH = 4096
[ ] adc_writer has capture_mode port
[ ] ctrl and writer sample_count are synchronized
[ ] ctrl and writer capture_mode are synchronized
[ ] ctrl start/clear pulse behavior implemented
[ ] ODDR fast path implemented or parameterized
[ ] no internal always @(posedge adc_clk_out)
[ ] AXI-Lite read data registered
[ ] PS notebook uses bare offsets only
[ ] fake writer mode tested before real ADC
[ ] capture_core fake stream mode tested before real ADC
```

## 17. Timing/Performance Hard Rules

```text
1. First version uses clk_125m as the only internal capture/control clock domain.
2. ADC_CLK is an external output clock to AD9226, not an internal FPGA clock.
3. First version includes ODDR-compatible ADC_CLK output.
4. adc_half_period=1 uses ODDR 62.5 MHz fast output by default.
5. ADC input data must pass 1~2 register stages before use.
6. sample_point_pulse in clk_125m domain decides when to latch ADC data.
7. PS config registers are latched into shadow config on start.
8. Busy-time config writes only affect next capture.
9. Illegal configs are clamped and config_error is set.
10. FIFO write path is only sample_valid && !fifo_full.
11. FIFO full drops samples and latches overflow; it must not stop ADC_CLK.
12. High-speed logic uses fifo_full/fifo_empty, not fifo_level comparisons.
13. AXI-Lite read data is registered.
14. sample_word packing is only concatenation of registered fields.
15. HLS writer only moves data; no algorithms.
16. No float, no division, no wide multiply, no FFT/DFT/CORDIC/sync_detector in PL.
17. First version keeps segmented DDR layout.
18. Interleaved layout or DMA is a later throughput optimization.
19. Digital WNS PASS does not prove external wiring works at 62.5 MHz.
20. LED/debug use registered status signals only.
21. Use PS-visible debug registers before adding ILA.
22. Adding ILA usually requires a new bitstream.
```
