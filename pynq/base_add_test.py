import numpy as np
from pynq import Overlay, allocate


overlay = Overlay("base_add.bit")
ip = overlay.base_add_0

MAX_SAMPLE_N = 1024
BUFFER_WORDS = MAX_SAMPLE_N * 2
sample_count = 1024

buf = allocate(shape=(BUFFER_WORDS,), dtype=np.int32)
buf[:] = 0
buf.flush()

addr = int(buf.physical_address)
try:
    ip.register_map.buffer = addr
    ip.register_map.sample_count = sample_count
except Exception:
    ip.write(0x10, addr & 0xFFFFFFFF)
    ip.write(0x18, sample_count)

ip.write(0x00, 0x01)

while (ip.read(0x00) & 0x2) == 0:
    pass

buf.invalidate()

ch0 = np.array(buf[:sample_count], dtype=np.int32)
ch1 = np.array(buf[MAX_SAMPLE_N:MAX_SAMPLE_N + sample_count], dtype=np.int32)

assert np.all(ch0 == np.arange(sample_count, dtype=np.int32))
assert np.all(ch1 == np.arange(sample_count - 1, -1, -1, dtype=np.int32))

print("CH0 first 8:", ch0[:8])
print("CH1 first 8:", ch1[:8])
print("FINAL: PASS")

buf.freebuffer()

