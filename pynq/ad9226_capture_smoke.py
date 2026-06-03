from time import time

import numpy as np
from pynq import Overlay, allocate


CTRL = 0x00
STATUS = 0x04
SAMPLE_COUNT = 0x08
ADC_HALF = 0x0C
SAMPLE_DELAY = 0x10
DECIMATION = 0x14
CHANNEL_MASK = 0x18
CAPTURE_MODE = 0x1C
TRIGGER_MODE = 0x20
PRE_DELAY = 0x24
BUFFER_SELECT = 0x28
LATEST_A = 0x2C
LATEST_B = 0x30
SAMPLE_COUNTER = 0x34
FIFO_LEVEL = 0x38
ERROR_FLAGS = 0x3C
LED_CTRL = 0x40
VERSION = 0x44
SAVED_COUNTER = 0x48
LAST_AXIS_WORD = 0x4C
DEBUG_STATE = 0x50
AXIS_SENT_COUNT = 0x54
AXIS_STALL_COUNT = 0x58
TLAST_COUNT = 0x5C
FIFO_BACKPRESSURE = 0x60
DROPPED_SAMPLE_COUNT = 0x64
CAPTURE_DONE_LATCHED = 0x68
CORE_DONE = 0x6C

S2MM_DMASR = 0x34
SENTINEL = np.uint32(0xDEADBEEF)
PL_CLK_HZ = 125_000_000
MAX_SAMPLE_N = 65536


def find_overlay_attr(overlay, text):
    matches = [name for name in overlay.ip_dict.keys() if text in name.lower()]
    if not matches:
        raise RuntimeError(f"Cannot find IP containing '{text}'. IPs: {list(overlay.ip_dict.keys())}")
    name = matches[0]
    if "/" in name:
        raise RuntimeError(f"IP '{name}' is hierarchical; open overlay.ip_dict and bind it manually.")
    return name, getattr(overlay, name)


def decode_dma_status(status):
    return {
        "raw": status,
        "halted": status & 0x1,
        "idle": (status >> 1) & 0x1,
        "dma_int_err": (status >> 4) & 0x1,
        "dma_slv_err": (status >> 5) & 0x1,
        "dma_dec_err": (status >> 6) & 0x1,
        "ioc_irq": (status >> 12) & 0x1,
        "err_irq": (status >> 14) & 0x1,
    }


def dump_dma(dma):
    status = dma.mmio.read(S2MM_DMASR)
    decoded = decode_dma_status(status)
    print("S2MM_DMASR      = 0x%08X" % status)
    for key, value in decoded.items():
        if key != "raw":
            print("%-16s= %d" % (key, value))


def dump_ctrl(ctrl):
    status = ctrl.read(STATUS)
    print("STATUS          = 0x%08X" % status)
    print("  busy          = %d" % ((status >> 0) & 0x1))
    print("  axis_done     = %d" % ((status >> 1) & 0x1))
    print("  fatal_error   = %d" % ((status >> 10) & 0x1))
    print("ERROR_FLAGS     = 0x%08X  (fatal + warning/debug)" % ctrl.read(ERROR_FLAGS))
    print("LATEST_A/B      = %d / %d" % (ctrl.read(LATEST_A), ctrl.read(LATEST_B)))
    print("SAMPLE_COUNTER  = %d" % ctrl.read(SAMPLE_COUNTER))
    print("FIFO_LEVEL      = %d" % ctrl.read(FIFO_LEVEL))
    print("SAVED_COUNTER   = %d" % ctrl.read(SAVED_COUNTER))
    print("LAST_AXIS_WORD  = 0x%08X" % ctrl.read(LAST_AXIS_WORD))
    print("DEBUG_STATE     = %d" % ctrl.read(DEBUG_STATE))
    print("AXIS_SENT_COUNT = %d" % ctrl.read(AXIS_SENT_COUNT))
    print("AXIS_STALL_COUNT= %d" % ctrl.read(AXIS_STALL_COUNT))
    print("TLAST_COUNT     = %d" % ctrl.read(TLAST_COUNT))
    print("FIFO_BACKPRESS  = %d" % ctrl.read(FIFO_BACKPRESSURE))
    print("DROPPED_SAMPLES = %d" % ctrl.read(DROPPED_SAMPLE_COUNT))
    print("CAPTURE_DONE    = %d" % ctrl.read(CAPTURE_DONE_LATCHED))
    print("CORE_DONE       = %d" % ctrl.read(CORE_DONE))
    print("VERSION         = 0x%08X" % ctrl.read(VERSION))


def configure_capture(ctrl, sample_count, adc_half_period, decimation, capture_mode, sample_delay=1):
    ctrl.write(CTRL, 0x04)
    ctrl.write(CTRL, 0x00)
    ctrl.write(ERROR_FLAGS, 0xFFFFFFFF)

    ctrl.write(SAMPLE_COUNT, sample_count)
    ctrl.write(ADC_HALF, adc_half_period)
    ctrl.write(SAMPLE_DELAY, sample_delay)
    ctrl.write(DECIMATION, decimation)
    ctrl.write(CHANNEL_MASK, 0b11)
    ctrl.write(CAPTURE_MODE, capture_mode)
    ctrl.write(TRIGGER_MODE, 0)
    ctrl.write(PRE_DELAY, 0)
    ctrl.write(BUFFER_SELECT, 0)


def run_dma_capture(ctrl, dma, sample_count=65536, adc_half_period=1, decimation=1, capture_mode=2, sample_delay=1):
    if capture_mode == 0:
        raise ValueError("capture_mode=0 is the legacy HLS-writer fake mode and is not valid for AXI DMA.")

    sample_count = min(max(int(sample_count), 1), MAX_SAMPLE_N)
    adc_half_period = max(int(adc_half_period), 1)
    decimation = max(int(decimation), 1)
    sample_delay = min(max(int(sample_delay), 0), 31)
    actual_fs = PL_CLK_HZ / (2 * adc_half_period)

    buf = allocate(shape=(sample_count,), dtype=np.uint32)
    buf[:] = SENTINEL
    buf.flush()

    dma.recvchannel.transfer(buf)
    configure_capture(ctrl, sample_count, adc_half_period, decimation, capture_mode, sample_delay)

    ctrl.write(CTRL, 0x01)
    ctrl.write(CTRL, 0x03)
    ctrl.write(CTRL, 0x01)

    t0 = time()
    dma.recvchannel.wait()
    elapsed = time() - t0
    buf.invalidate()

    raw = np.array(buf, dtype=np.uint32)
    ch0 = raw & np.uint32(0x0FFF)
    ch1 = (raw >> np.uint32(16)) & np.uint32(0x0FFF)

    print("DMA wait elapsed = %.6f s" % elapsed)
    print("target Fs        = %.3f MSPS" % (actual_fs / 1e6))
    print("sample_delay     = %d FCLK cycles" % sample_delay)
    dump_ctrl(ctrl)
    dump_dma(dma)

    if np.any(raw == SENTINEL):
        raise RuntimeError("DMA buffer still contains sentinel values; transfer length/TLAST may be wrong.")
    if ctrl.read(AXIS_SENT_COUNT) != sample_count:
        raise RuntimeError("AXIS_SENT_COUNT does not match sample_count.")
    if ctrl.read(TLAST_COUNT) != 1:
        raise RuntimeError("TLAST_COUNT is not 1.")
    if ctrl.read(DROPPED_SAMPLE_COUNT) != 0:
        raise RuntimeError("Dropped samples detected.")
    if (ctrl.read(STATUS) & (1 << 10)) != 0:
        raise RuntimeError("STATUS.fatal_error is set. Check overflow/dropped/config/DMA status.")

    return raw, ch0, ch1


def sweep_real_adc_sample_delay(ctrl, dma, sample_count=4096, adc_half_period=1, delays=(0, 1, 2, 3), decimation=1):
    results = []
    for delay in delays:
        print("\n=== real ADC sample_delay=%d ===" % delay)
        raw, ch0, ch1 = run_dma_capture(
            ctrl,
            dma,
            sample_count=sample_count,
            adc_half_period=adc_half_period,
            decimation=decimation,
            capture_mode=1,
            sample_delay=delay,
        )
        results.append({
            "sample_delay": delay,
            "ch0_vpp": int(ch0.max() - ch0.min()),
            "ch1_vpp": int(ch1.max() - ch1.min()),
            "ch0_mean": float(ch0.mean()),
            "ch1_mean": float(ch1.mean()),
        })
        print("delay=%d CH0 mean/Vpp %.2f/%d CH1 mean/Vpp %.2f/%d" % (
            delay,
            results[-1]["ch0_mean"],
            results[-1]["ch0_vpp"],
            results[-1]["ch1_mean"],
            results[-1]["ch1_vpp"],
        ))
    return results


def open_default_overlay(bitfile="base_add.bit"):
    overlay = Overlay(bitfile)
    ctrl_name, ctrl = find_overlay_attr(overlay, "adc_capture")
    dma_name, dma = find_overlay_attr(overlay, "dma")
    print("Loaded overlay.")
    print("IP names:", list(overlay.ip_dict.keys()))
    print("Capture IP:", ctrl_name, hex(overlay.ip_dict[ctrl_name]["phys_addr"]))
    print("DMA IP    :", dma_name, hex(overlay.ip_dict[dma_name]["phys_addr"]))
    print("Use IP-local offsets with ctrl.write(offset, value), do not add base address.")
    return overlay, ctrl, dma


def main():
    overlay, ctrl, dma = open_default_overlay()

    print("\nRunning capture_mode=2 fake stream -> AXIS FIFO -> AXI DMA -> DDR...")
    raw, ch0, ch1 = run_dma_capture(ctrl, dma, sample_count=65536, adc_half_period=1, capture_mode=2)

    expected = np.arange(len(ch0), dtype=np.uint32) & np.uint32(0x0FFF)
    if not np.array_equal(ch0, expected):
        raise RuntimeError(f"CH0 fake mismatch: got {ch0[:8].tolist()}, expected {expected[:8].tolist()}")
    if not np.array_equal(ch1, np.uint32(4095) - expected):
        raise RuntimeError("CH1 fake mismatch.")

    print("CH0 first 16:", ch0[:16].tolist())
    print("CH1 first 16:", ch1[:16].tolist())
    print("\nPASS: DMA fake-stream capture path is alive.")


if __name__ == "__main__":
    main()
