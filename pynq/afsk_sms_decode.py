import numpy as np

from ad9226_capture_smoke import open_default_overlay, run_dma_capture


PL_CLK_HZ = 125_000_000
ADC_HALF_PERIOD = 3125
FS_HZ = PL_CLK_HZ / (2 * ADC_HALF_PERIOD)
BIT_RATE = 100
BIT_SAMPLES = int(round(FS_HZ / BIT_RATE))

MARK_HZ = 2200.0
SPACE_HZ = 1200.0
MAX_SAMPLE_N = 65536


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


def tone_power(samples, freq_hz, fs_hz):
    x = samples.astype(np.float64)
    x = x - np.mean(x)
    n = np.arange(len(x), dtype=np.float64)
    phase = 2.0 * np.pi * freq_hz * n / fs_hz
    i = np.sum(x * np.cos(phase))
    q = np.sum(x * np.sin(phase))
    return i * i + q * q


def decide_bit(bit_samples):
    start = int(round(len(bit_samples) * 0.20))
    stop = int(round(len(bit_samples) * 0.80))
    center = bit_samples[start:stop]
    p0 = tone_power(center, SPACE_HZ, FS_HZ)
    p1 = tone_power(center, MARK_HZ, FS_HZ)
    return 1 if p1 > p0 else 0, p0, p1


def demod_bits(samples, offset):
    bits = []
    confidences = []
    usable = (len(samples) - offset) // BIT_SAMPLES
    for bit_index in range(usable):
        start = offset + bit_index * BIT_SAMPLES
        stop = start + BIT_SAMPLES
        bit, p0, p1 = decide_bit(samples[start:stop])
        bits.append(bit)
        confidences.append(abs(p1 - p0) / max(p0 + p1, 1.0))
    return bits, confidences


def bits_to_bytes_lsb(bits, bit_phase):
    out = []
    for start in range(bit_phase, len(bits) - 7, 8):
        value = 0
        for i in range(8):
            value |= (bits[start + i] & 1) << i
        out.append(value)
    return out


def find_frame(byte_values):
    for i in range(0, len(byte_values) - 8):
        if byte_values[i:i + 5] != [0xAA, 0xAA, 0xAA, 0xAA, 0x7E]:
            continue

        if i + 8 > len(byte_values):
            continue

        addr = byte_values[i + 5]
        length = byte_values[i + 6]
        end = i + 7 + length + 1
        if end > len(byte_values):
            continue

        payload = byte_values[i + 7:i + 7 + length]
        rx_crc = byte_values[i + 7 + length]
        calc_crc = crc8_0x07([addr, length] + payload)
        return {
            "byte_index": i,
            "addr": addr,
            "length": length,
            "payload": payload,
            "rx_crc": rx_crc,
            "calc_crc": calc_crc,
            "crc_ok": rx_crc == calc_crc,
        }
    return None


def search_afsk_frame(samples):
    best = None
    for offset in range(BIT_SAMPLES):
        bits, confidences = demod_bits(samples, offset)
        if len(bits) < 64:
            continue

        for bit_phase in range(8):
            byte_values = bits_to_bytes_lsb(bits, bit_phase)
            frame = find_frame(byte_values)
            if frame is None:
                continue

            first_bit = frame["byte_index"] * 8 + bit_phase
            score_slice = confidences[first_bit:first_bit + 40]
            score = float(np.mean(score_slice)) if score_slice else 0.0
            candidate = {
                "offset": offset,
                "bit_phase": bit_phase,
                "score": score,
                "frame": frame,
                "bytes": byte_values,
            }
            if best is None or candidate["score"] > best["score"]:
                best = candidate
    return best


def printable_payload(payload):
    chars = []
    for byte in payload:
        if 32 <= byte <= 126:
            chars.append(chr(byte))
        else:
            chars.append(".")
    return "".join(chars)


def main():
    print("AFSK SMS decode using PS-side buffered ADC analysis")
    print("FS_HZ        = %.1f" % FS_HZ)
    print("BIT_SAMPLES  = %d" % BIT_SAMPLES)
    print("Capture time = %.3f s" % (MAX_SAMPLE_N / FS_HZ))

    _, ctrl, dma = open_default_overlay()
    _, ch0, ch1 = run_dma_capture(
        ctrl,
        dma,
        sample_count=MAX_SAMPLE_N,
        adc_half_period=ADC_HALF_PERIOD,
        decimation=1,
        capture_mode=1,
        sample_delay=1,
    )

    for name, channel in (("CH0", ch0), ("CH1", ch1)):
        print("\nSearching", name)
        samples = channel.astype(np.float64)
        result = search_afsk_frame(samples)
        if result is None:
            print("No valid 0xAA 0xAA 0xAA 0xAA 0x7E frame found.")
            continue

        frame = result["frame"]
        text = printable_payload(frame["payload"])
        print("offset/phase = %d / %d" % (result["offset"], result["bit_phase"]))
        print("score        = %.4f" % result["score"])
        print("addr         = 0x%02X" % frame["addr"])
        print("length       = %d" % frame["length"])
        print("payload      =", text)
        print("crc rx/calc  = 0x%02X / 0x%02X" % (frame["rx_crc"], frame["calc_crc"]))
        print("crc_ok       =", frame["crc_ok"])


if __name__ == "__main__":
    main()
