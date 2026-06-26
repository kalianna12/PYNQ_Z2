#!/usr/bin/env python3
from __future__ import print_function

import json
import os
from time import time

import numpy as np
from pynq import Overlay, allocate

try:
    import serial
except ImportError as exc:
    raise SystemExit("pyserial is required: sudo pip3 install pyserial") from exc


BITFILE = os.environ.get("AFSK_BITFILE", "base_add.bit")
UART_DEV = os.environ.get("AFSK_UART_DEV", "/dev/ttyUSB0")
UART_BAUD = int(os.environ.get("AFSK_UART_BAUD", "115200"))
CHANNEL = os.environ.get("AFSK_CHANNEL", "ch0").lower()
LOCAL_ADDR_ENV = os.environ.get("AFSK_LOCAL_ADDR", "")
LOCAL_ADDR = None if LOCAL_ADDR_ENV == "" else int(LOCAL_ADDR_ENV, 0)

PL_CLK_HZ = 125_000_000
ADC_HALF_PERIOD = 3125
FS_HZ = PL_CLK_HZ / (2 * ADC_HALF_PERIOD)
BIT_RATE = 100.0
BIT_SAMPLES = int(round(FS_HZ / BIT_RATE))
SAMPLE_COUNT = int(os.environ.get("AFSK_SAMPLE_COUNT", "65536"))

SPACE_HZ = 1200.0
MARK_HZ = 2200.0
CENTER_FRACTION = 0.60
FAST_OFFSET_STRIDE = 10
MIN_ALT_BITS = 24
INVERT_BITS = True
MAX_ATTEMPTS = int(os.environ.get("AFSK_MAX_ATTEMPTS", "60"))

CTRL = 0x00
STATUS = 0x04
SAMPLE_COUNT_REG = 0x08
ADC_HALF = 0x0C
SAMPLE_DELAY = 0x10
DECIMATION = 0x14
CHANNEL_MASK = 0x18
CAPTURE_MODE = 0x1C
TRIGGER_MODE = 0x20
PRE_DELAY = 0x24
BUFFER_SELECT = 0x28
ERROR_FLAGS = 0x3C
AXIS_SENT_COUNT = 0x54
TLAST_COUNT = 0x5C
DROPPED_SAMPLE_COUNT = 0x64
SENTINEL = np.uint32(0xDEADBEEF)


def line_json(kind, **fields):
    data = {"kind": kind}
    data.update(fields)
    return json.dumps(data, separators=(",", ":"))


def find_overlay_attr(overlay, text):
    matches = [name for name in overlay.ip_dict.keys() if text in name.lower()]
    if not matches:
        raise RuntimeError("Cannot find IP containing %r. IPs: %r" % (text, list(overlay.ip_dict.keys())))
    name = matches[0]
    if "/" in name:
        raise RuntimeError("IP %r is hierarchical; bind it manually." % name)
    return name, getattr(overlay, name)


def configure_capture(ctrl, sample_count, adc_half_period, capture_mode):
    ctrl.write(CTRL, 0x04)
    ctrl.write(CTRL, 0x00)
    ctrl.write(ERROR_FLAGS, 0xFFFFFFFF)
    ctrl.write(SAMPLE_COUNT_REG, int(sample_count))
    ctrl.write(ADC_HALF, int(adc_half_period))
    ctrl.write(SAMPLE_DELAY, 1)
    ctrl.write(DECIMATION, 1)
    ctrl.write(CHANNEL_MASK, 0b11)
    ctrl.write(CAPTURE_MODE, int(capture_mode))
    ctrl.write(TRIGGER_MODE, 0)
    ctrl.write(PRE_DELAY, 0)
    ctrl.write(BUFFER_SELECT, 0)


def capture_once(ctrl, dma, sample_count=SAMPLE_COUNT, adc_half_period=ADC_HALF_PERIOD, capture_mode=1):
    sample_count = int(min(max(sample_count, 1), 65536))
    buf = allocate(shape=(sample_count,), dtype=np.uint32)
    buf[:] = SENTINEL
    buf.flush()

    dma.recvchannel.transfer(buf)
    configure_capture(ctrl, sample_count, adc_half_period, capture_mode)
    ctrl.write(CTRL, 0x01)
    ctrl.write(CTRL, 0x03)
    ctrl.write(CTRL, 0x01)
    dma.recvchannel.wait()
    buf.invalidate()

    raw = np.array(buf, dtype=np.uint32)
    ch0 = (raw & np.uint32(0x0FFF)).astype(np.float64)
    ch1 = ((raw >> np.uint32(16)) & np.uint32(0x0FFF)).astype(np.float64)

    if np.any(raw == SENTINEL):
        raise RuntimeError("DMA buffer still contains sentinel values.")
    if ctrl.read(AXIS_SENT_COUNT) != sample_count:
        raise RuntimeError("AXIS_SENT_COUNT mismatch.")
    if ctrl.read(TLAST_COUNT) != 1:
        raise RuntimeError("TLAST_COUNT is not 1.")
    if ctrl.read(DROPPED_SAMPLE_COUNT) != 0:
        raise RuntimeError("Dropped samples detected.")
    if (ctrl.read(STATUS) & (1 << 10)) != 0:
        raise RuntimeError("STATUS.fatal_error is set.")

    return raw, ch0, ch1


def crc8_0x07(data):
    crc = 0
    for byte in data:
        crc ^= byte & 0xFF
        for _ in range(8):
            if crc & 0x80:
                crc = ((crc << 1) ^ 0x07) & 0xFF
            else:
                crc = (crc << 1) & 0xFF
    return crc


def bytes_to_ascii(values):
    return "".join(chr(v) if 32 <= v <= 126 else "." for v in values)


def bits_to_bytes_lsb(bits, phase):
    out = []
    for start in range(phase, len(bits) - 7, 8):
        value = 0
        for i in range(8):
            value |= (bits[start + i] & 1) << i
        out.append(value)
    return out


def find_frame(byte_values):
    sync = [0xAA, 0xAA, 0xAA, 0xAA, 0x7E]
    for i in range(0, len(byte_values) - len(sync) - 3):
        if byte_values[i:i + len(sync)] != sync:
            continue
        base = i + len(sync)
        addr = byte_values[base]
        length = byte_values[base + 1]
        end = base + 2 + length + 1
        addr_ok = (LOCAL_ADDR is None) or (addr == LOCAL_ADDR) or (addr == 0xFF)
        if end > len(byte_values):
            return {
                "status": "incomplete",
                "byte_index": i,
                "addr": addr,
                "length": length,
                "payload": [],
                "rx_crc": None,
                "calc_crc": None,
                "crc_ok": False,
                "addr_ok": addr_ok,
            }
        payload = byte_values[base + 2:base + 2 + length]
        rx_crc = byte_values[base + 2 + length]
        calc_crc = crc8_0x07([addr, length] + payload)
        return {
            "status": "complete",
            "byte_index": i,
            "addr": addr,
            "length": length,
            "payload": payload,
            "rx_crc": rx_crc,
            "calc_crc": calc_crc,
            "crc_ok": rx_crc == calc_crc,
            "addr_ok": addr_ok,
        }
    return None


def demod_bits(samples, offset):
    x = samples.astype(np.float64)
    x = x - np.mean(x)

    margin = (1.0 - CENTER_FRACTION) * 0.5
    center_start = int(round(BIT_SAMPLES * margin))
    center_stop = int(round(BIT_SAMPLES * (1.0 - margin)))
    win_n = center_stop - center_start

    n = np.arange(win_n, dtype=np.float64)
    c1200 = np.cos(2.0 * np.pi * SPACE_HZ * n / FS_HZ)
    s1200 = np.sin(2.0 * np.pi * SPACE_HZ * n / FS_HZ)
    c2200 = np.cos(2.0 * np.pi * MARK_HZ * n / FS_HZ)
    s2200 = np.sin(2.0 * np.pi * MARK_HZ * n / FS_HZ)

    bits = []
    confs = []
    bit_count = (len(x) - offset) // BIT_SAMPLES
    for k in range(bit_count):
        a = offset + k * BIT_SAMPLES + center_start
        b = offset + k * BIT_SAMPLES + center_stop
        seg = x[a:b]
        if len(seg) != win_n:
            break
        seg = seg - np.mean(seg)
        e1200 = np.dot(seg, c1200) ** 2 + np.dot(seg, s1200) ** 2
        e2200 = np.dot(seg, c2200) ** 2 + np.dot(seg, s2200) ** 2
        bit = 1 if e2200 > e1200 else 0
        if INVERT_BITS:
            bit ^= 1
        conf = abs(e2200 - e1200) / max(e2200 + e1200, 1.0)
        bits.append(bit)
        confs.append(conf)
    return bits, confs


def best_0101(bits, confs):
    best = {"score": -1.0, "start": 0, "length": 0, "polarity": 0}
    for polarity in (0, 1):
        run_start = 0
        run_len = 0
        run_conf = []
        for i, bit in enumerate(bits):
            expected = (i + polarity) & 1
            if bit == expected:
                if run_len == 0:
                    run_start = i
                    run_conf = []
                run_len += 1
                run_conf.append(confs[i] if i < len(confs) else 0.0)
            else:
                if run_len >= MIN_ALT_BITS:
                    score = run_len + float(np.mean(run_conf))
                    if score > best["score"]:
                        best = {"score": score, "start": run_start, "length": run_len, "polarity": polarity}
                run_len = 0
                run_conf = []
        if run_len >= MIN_ALT_BITS:
            score = run_len + float(np.mean(run_conf))
            if score > best["score"]:
                best = {"score": score, "start": run_start, "length": run_len, "polarity": polarity}
    return best


def search_frame(samples):
    best = {
        "frame": None,
        "score": -1.0,
        "offset": 0,
        "phase": 0,
        "preamble_bit": 0,
        "preamble_len": 0,
        "bits": [],
    }
    for offset in range(0, BIT_SAMPLES, FAST_OFFSET_STRIDE):
        bits, confs = demod_bits(samples, offset)
        alt = best_0101(bits, confs)
        if alt["score"] > best["score"]:
            best.update({
                "score": alt["score"],
                "offset": offset,
                "phase": alt["start"] % 8,
                "preamble_bit": alt["start"],
                "preamble_len": alt["length"],
                "bits": bits,
            })
        for phase in range(8):
            byte_values = bits_to_bytes_lsb(bits, phase)
            frame = find_frame(byte_values)
            if frame is not None:
                return {
                    "frame": frame,
                    "score": alt["score"],
                    "offset": offset,
                    "phase": phase,
                    "preamble_bit": alt["start"],
                    "preamble_len": alt["length"],
                    "bits": bits,
                    "bytes": byte_values,
                }
    return best


def select_channel(ch0, ch1):
    if CHANNEL == "ch1":
        return ch1
    return ch0


class ReceiverService:
    def __init__(self, uart):
        self.uart = uart
        self.overlay = None
        self.ctrl = None
        self.dma = None

    def send(self, kind, **fields):
        msg = line_json(kind, **fields)
        print(msg, flush=True)
        self.uart.write((msg + "\n").encode("ascii"))
        self.uart.flush()

    def load_overlay(self):
        self.send("status", result="BOOTING", text="loading overlay", bitfile=BITFILE)
        self.overlay = Overlay(BITFILE)
        ctrl_name, self.ctrl = find_overlay_attr(self.overlay, "adc_capture")
        dma_name, self.dma = find_overlay_attr(self.overlay, "dma")
        self.send("status", result="OK", ctrl=ctrl_name, dma=dma_name, fs_hz=FS_HZ, bit_samples=BIT_SAMPLES)

    def test_bit(self):
        self.send("test", state="capturing")
        _, ch0, ch1 = capture_once(self.ctrl, self.dma, sample_count=4096, capture_mode=1)
        samples = select_channel(ch0, ch1)
        samples = samples - np.mean(samples)
        window_n = int(round(FS_HZ * 4 / SPACE_HZ))
        seg = samples[:window_n]
        p1200 = tone_power(seg, SPACE_HZ)
        p2200 = tone_power(seg, MARK_HZ)
        raw_bit = 1 if p2200 > p1200 else 0
        bit = raw_bit ^ (1 if INVERT_BITS else 0)
        measured_hz = 2200.0 if p2200 > p1200 else 1200.0
        confidence = abs(p2200 - p1200) / max(p2200 + p1200, 1.0)
        result = str(int(bit)) if confidence >= 0.25 else "FAIL"
        self.send(
            "test",
            state="done",
            result=result,
            bit=int(bit),
            confidence=confidence,
            measured_hz=measured_hz,
            e1200=p1200,
            e2200=p2200,
            vpp=float(np.max(seg) - np.min(seg)),
        )

    def capture_sms(self):
        for attempt in range(1, MAX_ATTEMPTS + 1):
            self.send("attempt", attempt=attempt, state="capturing")
            t0 = time()
            _, ch0, ch1 = capture_once(self.ctrl, self.dma, capture_mode=1)
            samples = select_channel(ch0, ch1)
            self.send("attempt", attempt=attempt, state="decoding")
            result = search_frame(samples)
            elapsed = time() - t0
            preamble_ms = (result["offset"] + result["preamble_bit"] * BIT_SAMPLES) / FS_HZ * 1000.0
            self.send(
                "attempt",
                attempt=attempt,
                state="done",
                elapsed_s=elapsed,
                score=result["score"],
                offset=result["offset"],
                phase=result["phase"],
                preamble_ms=preamble_ms,
                preamble_len=result["preamble_len"],
            )
            frame = result["frame"]
            if frame is None:
                continue
            payload = bytes_to_ascii(frame["payload"]) if frame["status"] == "complete" else ""
            self.send(
                "sms",
                status=frame["status"],
                addr=frame["addr"],
                addr_ok=frame["addr_ok"],
                length=frame["length"],
                payload=payload,
                payload_hex=" ".join("%02X" % b for b in frame["payload"]),
                rx_crc=frame["rx_crc"],
                calc_crc=frame["calc_crc"],
                crc_ok=frame["crc_ok"],
            )
            return
        self.send("sms", status="not_found")

    def handle_line(self, line):
        line = line.strip()
        if not line:
            return
        upper = line.upper()
        try:
            if upper == "STATUS":
                self.send("status", result="OK", fs_hz=FS_HZ, channel=CHANNEL, invert_bits=INVERT_BITS)
            elif upper == "TEST":
                self.test_bit()
            elif upper == "CAPTURE":
                self.capture_sms()
            else:
                self.send("status", result="ERROR", text="unknown command", command=line)
        except Exception as exc:
            self.send("status", result="ERROR", text=str(exc))

    def run(self):
        self.load_overlay()
        self.send("status", result="OK", text="waiting for commands", uart=UART_DEV, baud=UART_BAUD)
        while True:
            raw = self.uart.readline()
            if not raw:
                continue
            try:
                line = raw.decode("ascii", errors="ignore")
            except Exception:
                continue
            self.handle_line(line)


def tone_power(samples, freq_hz):
    x = samples.astype(np.float64)
    x = x - np.mean(x)
    n = np.arange(len(x), dtype=np.float64)
    phase = 2.0 * np.pi * freq_hz * n / FS_HZ
    i = np.sum(x * np.cos(phase))
    q = np.sum(x * np.sin(phase))
    return i * i + q * q


def main():
    with serial.Serial(UART_DEV, UART_BAUD, timeout=0.2) as uart:
        service = ReceiverService(uart)
        service.run()


if __name__ == "__main__":
    main()
