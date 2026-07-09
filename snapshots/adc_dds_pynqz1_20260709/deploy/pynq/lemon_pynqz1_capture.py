from time import time

import numpy as np
from pynq import MMIO, Overlay, allocate


BITFILE = "base_add.bit"

LED_BASE = 0x40000000
LED_RANGE = 0x1000
ADC_BASE = 0x40001000
ADC_RANGE = 0x1000

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
ADC_SAMPLE_HZ = 62_500_000
MAX_SAMPLE_N = 262144


def find_dma(overlay):
    if hasattr(overlay, "axi_dma_0") and hasattr(overlay.axi_dma_0, "recvchannel"):
        return overlay.axi_dma_0
    for name in overlay.ip_dict:
        if "dma" in name.lower():
            obj = getattr(overlay, name)
            if hasattr(obj, "recvchannel"):
                return obj
    raise RuntimeError("Cannot find DMA object with recvchannel. IPs: %s" % list(overlay.ip_dict.keys()))


def open_default_overlay(bitfile=BITFILE):
    overlay = Overlay(bitfile)
    led_ip = MMIO(LED_BASE, LED_RANGE)
    adc_ip = MMIO(ADC_BASE, ADC_RANGE)
    dma = find_dma(overlay)

    print("Loaded overlay:", bitfile)
    print("led_ctrl_0    : MMIO(0x%08X, 0x%X)" % (LED_BASE, LED_RANGE))
    print("adc_capture_0 : MMIO(0x%08X, 0x%X)" % (ADC_BASE, ADC_RANGE))
    print("DMA object    :", dma)
    print("IP dictionary :", list(overlay.ip_dict.keys()))

    return overlay, adc_ip, dma


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
    print("ERROR_FLAGS     = 0x%08X" % ctrl.read(ERROR_FLAGS))
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


def configure_capture(ctrl, sample_count, adc_half_period, decimation, capture_mode, sample_delay=0):
    ctrl.write(CTRL, 0x04)
    ctrl.write(CTRL, 0x00)
    ctrl.write(ERROR_FLAGS, 0xFFFFFFFF)
    ctrl.write(SAMPLE_COUNT, sample_count)
    # Fixed-speed RTL keeps these legacy registers for address compatibility.
    ctrl.write(ADC_HALF, 1)
    ctrl.write(SAMPLE_DELAY, 0)
    ctrl.write(DECIMATION, decimation)
    ctrl.write(CHANNEL_MASK, 0b11)
    ctrl.write(CAPTURE_MODE, capture_mode)
    ctrl.write(TRIGGER_MODE, 0)
    ctrl.write(PRE_DELAY, 0)
    ctrl.write(BUFFER_SELECT, 0)


def run_dma_capture(ctrl, dma, sample_count=65536, adc_half_period=1, decimation=1,
                    capture_mode=2, sample_delay=0, verbose=True):
    if capture_mode == 0:
        raise ValueError("capture_mode=0 is not valid for AXI DMA.")

    sample_count = min(max(int(sample_count), 1), MAX_SAMPLE_N)
    adc_half_period = max(int(adc_half_period), 1)
    decimation = max(int(decimation), 1)
    sample_delay = min(max(int(sample_delay), 0), 31)
    physical_fs = float(ADC_SAMPLE_HZ)
    actual_fs = physical_fs / decimation

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

    if verbose:
        print("DMA wait elapsed = %.6f s" % elapsed)
        print("physical ADC Fs  = %.3f MSPS (fixed)" % (physical_fs / 1e6))
        print("saved sample Fs  = %.3f MSPS" % (actual_fs / 1e6))
        print("decimation       = %d" % decimation)
        if adc_half_period != 1 or sample_delay != 0:
            print("legacy half_period/sample_delay arguments are ignored")
        dump_ctrl(ctrl)
        dump_dma(dma)

    if np.any(raw == SENTINEL):
        raise RuntimeError("DMA buffer still contains sentinel values.")
    if ctrl.read(AXIS_SENT_COUNT) != sample_count:
        raise RuntimeError("AXIS_SENT_COUNT mismatch: %d != %d" % (ctrl.read(AXIS_SENT_COUNT), sample_count))
    if ctrl.read(TLAST_COUNT) != 1:
        raise RuntimeError("TLAST_COUNT is not 1.")
    if ctrl.read(DROPPED_SAMPLE_COUNT) != 0:
        raise RuntimeError("Dropped samples detected.")
    if (ctrl.read(STATUS) & (1 << 10)) != 0:
        raise RuntimeError("STATUS.fatal_error is set.")

    return raw, ch0, ch1


def main():
    _, ctrl, dma = open_default_overlay()
    print("\nRunning capture_mode=2 fake stream -> AXIS FIFO -> AXI DMA -> DDR...")
    raw, ch0, ch1 = run_dma_capture(ctrl, dma, sample_count=65536, adc_half_period=1, capture_mode=2)

    expected = np.arange(len(ch0), dtype=np.uint32) & np.uint32(0x0FFF)
    if not np.array_equal(ch0, expected):
        raise RuntimeError("CH0 fake mismatch.")
    if not np.array_equal(ch1, np.uint32(4095) - expected):
        raise RuntimeError("CH1 fake mismatch.")

    print("CH0 first 16:", ch0[:16].tolist())
    print("CH1 first 16:", ch1[:16].tolist())
    print("\nPASS: Lemon/PYNQ-Z1 DMA fake-stream capture path is alive.")


if __name__ == "__main__":
    main()
