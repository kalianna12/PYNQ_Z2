from pynq import Overlay


overlay = Overlay("base_add.bit")
print(overlay.ip_dict)

ip = overlay.base_add_0

a = 123
b = 456

ip.write(0x10, a)
ip.write(0x18, b)
ip.write(0x00, 0x01)

while (ip.read(0x00) & 0x2) == 0:
    pass

result = ip.read(0x20)
print(f"{a} + {b} = {result}")

assert result == a + b
print("PASS")

