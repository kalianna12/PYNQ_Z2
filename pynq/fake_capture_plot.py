import time

import matplotlib.pyplot as plt
import numpy as np
from pynq import Overlay, allocate


MAX_SAMPLE_N = 1024
BUFFER_WORDS = MAX_SAMPLE_N * 2
SAMPLE_COUNT = 1024


def wait_done(ip, timeout_s=2.0):
    start = time.time()
    while (ip.read(0x00) & 0x2) == 0:
        if time.time() - start > timeout_s:
            raise TimeoutError("HLS IP timeout waiting for ap_done")


overlay = Overlay("base_add.bit")
ip = overlay.base_add_0

print("Loaded overlay IPs:")
print(overlay.ip_dict.keys())
print("\nHLS IP register map:")
print(ip.register_map)

buf = allocate(shape=(BUFFER_WORDS,), dtype=np.int32)
buf[:] = 0
buf.flush()

sample_count = min(SAMPLE_COUNT, MAX_SAMPLE_N)
phys_addr = int(buf.physical_address)

print(f"\nBuffer physical address: 0x{phys_addr:08x}")
print(f"Sample count: {sample_count}")

try:
    ip.register_map.buffer = phys_addr
    ip.register_map.sample_count = sample_count
except Exception:
    # Vivado HLS 2018.2 usually maps:
    # 0x10 = buffer physical address, 0x18 = sample_count.
    ip.write(0x10, phys_addr & 0xFFFFFFFF)
    ip.write(0x18, sample_count)

ip.write(0x00, 0x01)
wait_done(ip)

buf.invalidate()

ch0 = np.array(buf[:sample_count], dtype=np.int32)
ch1 = np.array(buf[MAX_SAMPLE_N:MAX_SAMPLE_N + sample_count], dtype=np.int32)

print("\nFirst 8 samples:")
print("CH0:", ch0[:8])
print("CH1:", ch1[:8])

assert np.all(ch0 == np.arange(sample_count, dtype=np.int32))
assert np.all(ch1 == np.arange(sample_count - 1, -1, -1, dtype=np.int32))
print("\nFINAL: PASS")

plt.figure(figsize=(10, 4))
plt.plot(ch0, label="CH0 fake ramp")
plt.plot(ch1, label="CH1 fake reverse ramp")
plt.title("PYNQ-Z2 HLS m_axi Fake Capture")
plt.xlabel("Sample Index")
plt.ylabel("Sample Value")
plt.grid(True)
plt.legend()
plt.tight_layout()
plt.savefig("fake_capture_plot.png", dpi=150)
plt.show()

buf.freebuffer()
