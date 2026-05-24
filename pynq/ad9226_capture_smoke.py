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
LAST_SAMPLE_WORD = 0x4C
DEBUG_STATE = 0x50

# HLS writer offsets copied from generated xbase_add_hw.h.
WRITER_AP_CTRL = 0x00
WRITER_BUFFER = 0x10
WRITER_SAMPLE_COUNT = 0x18
WRITER_CAPTURE_MODE = 0x20

MAX_SAMPLE_N = 65536


def read_status(ctrl):
    status = ctrl.read(STATUS)
    return {
        "STATUS": status,
        "busy": status & 0x1,
        "done": (status >> 1) & 0x1,
        "adc_clk_seen": (status >> 2) & 0x1,
        "fifo_full": (status >> 3) & 0x1,
        "fifo_empty": (status >> 4) & 0x1,
        "fifo_overflow": (status >> 5) & 0x1,
        "near_rail_a": (status >> 6) & 0x1,
        "near_rail_b": (status >> 7) & 0x1,
        "error": (status >> 10) & 0x1,
        "data_changed_a": (status >> 11) & 0x1,
        "data_changed_b": (status >> 12) & 0x1,
    }


def dump_regs(ctrl):
    s = read_status(ctrl)
    for key, value in s.items():
        if key == "STATUS":
            print(f"{key:16s}= 0x{value:08X}")
        else:
            print(f"{key:16s}= {value}")
    print(f"LATEST_A        = {ctrl.read(LATEST_A)}")
    print(f"LATEST_B        = {ctrl.read(LATEST_B)}")
    print(f"SAMPLE_COUNTER  = {ctrl.read(SAMPLE_COUNTER)}")
    print(f"SAVED_COUNTER   = {ctrl.read(SAVED_COUNTER)}")
    print(f"FIFO_LEVEL      = {ctrl.read(FIFO_LEVEL)}")
    print(f"ERROR_FLAGS     = 0x{ctrl.read(ERROR_FLAGS):08X}")
    print(f"LAST_SAMPLE     = 0x{ctrl.read(LAST_SAMPLE_WORD):08X}")
    print(f"DEBUG_STATE     = {ctrl.read(DEBUG_STATE)}")
    print(f"VERSION         = 0x{ctrl.read(VERSION):08X}")


def wait_writer_done(writer, timeout_s=2.0):
    t0 = time()
    while True:
        ap_ctrl = writer.read(WRITER_AP_CTRL)
        if (ap_ctrl >> 1) & 1:
            return ap_ctrl
        if time() - t0 > timeout_s:
            raise TimeoutError(f"writer timeout, AP_CTRL=0x{ap_ctrl:08X}")


def alloc_buffer():
    buf = allocate(shape=(2 * MAX_SAMPLE_N,), dtype=np.int32)
    buf[:] = -12345
    buf.flush()
    return buf


def run_writer_fake(writer, sample_count=32):
    sample_count = min(max(int(sample_count), 1), MAX_SAMPLE_N)
    buf = alloc_buffer()

    writer.write(WRITER_BUFFER, buf.physical_address)
    writer.write(WRITER_SAMPLE_COUNT, sample_count)
    writer.write(WRITER_CAPTURE_MODE, 0)
    writer.write(WRITER_AP_CTRL, 0x01)

    wait_writer_done(writer)
    buf.invalidate()

    ch0 = np.array(buf[0:sample_count], dtype=np.int32)
    ch1 = np.array(buf[MAX_SAMPLE_N:MAX_SAMPLE_N + sample_count], dtype=np.int32)
    phase = np.arange(sample_count, dtype=np.int32) & 255
    expected_ch0 = np.where(phase < 128, phase * 16, (255 - phase) * 16).astype(np.int32)
    expected_ch1 = (expected_ch0 // 2).astype(np.int32)
    if not np.array_equal(ch0, expected_ch0):
        raise RuntimeError(f"writer fake CH0 mismatch: got {ch0[:8].tolist()}, expected {expected_ch0[:8].tolist()}")
    if not np.array_equal(ch1, expected_ch1):
        raise RuntimeError(f"writer fake CH1 mismatch: got {ch1[:8].tolist()}, expected {expected_ch1[:8].tolist()}")
    print("writer fake ch0 first 8:", ch0[:8].tolist())
    print("writer fake ch1 first 8:", ch1[:8].tolist())
    return buf


def run_capture_core_fake_to_ddr(ctrl, writer, sample_count=32, adc_half_period=6, timeout_s=2.0):
    sample_count = min(max(int(sample_count), 1), MAX_SAMPLE_N)
    adc_half_period = max(int(adc_half_period), 1)
    buf = alloc_buffer()

    ctrl.write(CTRL, 0x04)
    ctrl.write(CTRL, 0x00)

    ctrl.write(SAMPLE_COUNT, sample_count)
    ctrl.write(ADC_HALF, adc_half_period)
    ctrl.write(SAMPLE_DELAY, 1)
    ctrl.write(DECIMATION, 1)
    ctrl.write(CHANNEL_MASK, 0b11)
    ctrl.write(CAPTURE_MODE, 2)
    ctrl.write(TRIGGER_MODE, 0)
    ctrl.write(PRE_DELAY, 0)
    ctrl.write(BUFFER_SELECT, 0)

    writer.write(WRITER_BUFFER, buf.physical_address)
    writer.write(WRITER_SAMPLE_COUNT, sample_count)
    writer.write(WRITER_CAPTURE_MODE, 2)
    writer.write(WRITER_AP_CTRL, 0x01)

    ctrl.write(CTRL, 0x01)
    ctrl.write(CTRL, 0x03)
    ctrl.write(CTRL, 0x01)

    t0 = time()
    while True:
        status = ctrl.read(STATUS)
        ctrl_done = (status >> 1) & 1
        writer_ctrl = writer.read(WRITER_AP_CTRL)
        writer_done = (writer_ctrl >> 1) & 1
        if ctrl_done and writer_done:
            break
        if time() - t0 > timeout_s:
            dump_regs(ctrl)
            raise TimeoutError(
                f"capture_mode=2 full-chain timeout, writer AP_CTRL=0x{writer_ctrl:08X}"
            )

    buf.invalidate()
    dump_regs(ctrl)
    ch0 = np.array(buf[0:sample_count], dtype=np.int32)
    ch1 = np.array(buf[MAX_SAMPLE_N:MAX_SAMPLE_N + sample_count], dtype=np.int32)

    expected_ch0 = np.arange(sample_count, dtype=np.int32) & 0xFFF
    expected_ch1 = 4095 - expected_ch0
    if not np.array_equal(ch0, expected_ch0):
        raise RuntimeError(f"CH0 mismatch: got {ch0[:8].tolist()}, expected {expected_ch0[:8].tolist()}")
    if not np.array_equal(ch1, expected_ch1):
        raise RuntimeError(f"CH1 mismatch: got {ch1[:8].tolist()}, expected {expected_ch1[:8].tolist()}")

    print("capture_core fake stream ch0 first 8:", ch0[:8].tolist())
    print("capture_core fake stream ch1 first 8:", ch1[:8].tolist())
    return buf


overlay = Overlay("base_add.bit")
print("Loaded overlay.")
print("IP names:", list(overlay.ip_dict.keys()))

ctrl = overlay.adc_capture_0
writer = overlay.base_add_0
base_addr = overlay.ip_dict["adc_capture_0"].get("phys_addr", None)
writer_addr = overlay.ip_dict["base_add_0"].get("phys_addr", None)
print("adc_capture_0 base address from hwh:", hex(base_addr) if base_addr is not None else "unknown")
print("base_add_0 writer base address from hwh:", hex(writer_addr) if writer_addr is not None else "unknown")
print("Use IP-local offsets with ctrl.write(offset, value), do not add base address.")

print("\nInitial registers:")
dump_regs(ctrl)

print("\nRunning capture_mode=0 writer fake -> DDR...")
run_writer_fake(writer, sample_count=32)

print("\nRunning capture_mode=2 capture_core fake stream -> FIFO -> writer -> DDR...")
run_capture_core_fake_to_ddr(ctrl, writer, sample_count=32, adc_half_period=6)

print("\nPASS: writer fake and capture_core fake stream full DDR path are alive.")
