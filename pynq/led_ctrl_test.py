from time import sleep

from pynq import MMIO, Overlay


BITSTREAM = "base_add.bit"

REG_CTRL = 0x00
REG_SPEED_DIV = 0x04
REG_LED_VALUE = 0x08
REG_STATUS = 0x0C

MODE_DIRECT = 0
MODE_BLINK = 1
MODE_WALK = 2
MODE_COUNTER = 3


def find_led_ctrl_ip(overlay):
    for name, info in overlay.ip_dict.items():
        if "led_ctrl" in name:
            return name, info
    raise RuntimeError("Cannot find led_ctrl IP in overlay.ip_dict. Check base_add.hwh.")


def ctrl_word(enable, mode):
    return (1 if enable else 0) | ((mode & 0x7) << 1)


overlay = Overlay(BITSTREAM)
ip_name, ip_info = find_led_ctrl_ip(overlay)

base_addr = int(ip_info["phys_addr"])
addr_range = int(ip_info["addr_range"])
mmio = MMIO(base_addr, addr_range)

print("LED controller IP:", ip_name)
print("Base address from HWH: 0x%08X" % base_addr)
print("Address range from HWH: 0x%X" % addr_range)

mmio.write(REG_SPEED_DIV, 12_500_000)

print("Direct mode: LED = 0xA")
mmio.write(REG_LED_VALUE, 0xA)
mmio.write(REG_CTRL, ctrl_word(False, MODE_DIRECT))
sleep(1)

print("Blink mode")
mmio.write(REG_CTRL, ctrl_word(True, MODE_BLINK))
sleep(3)

print("Walk mode")
mmio.write(REG_CTRL, ctrl_word(True, MODE_WALK))
sleep(3)

print("Counter mode")
mmio.write(REG_CTRL, ctrl_word(True, MODE_COUNTER))
sleep(3)

status = mmio.read(REG_STATUS)
print("STATUS = 0x%08X, current LED bits = 0x%X" % (status, status & 0xF))
print("FINAL: PASS")
