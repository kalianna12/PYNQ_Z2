from time import monotonic, sleep

from pynq import MMIO


AD9102_BASE = 0x40002000
AD9102_RANGE = 0x1000
AD9102_DAC_CLK_HZ = 180_000_000
AD9102_RECOMMENDED_MAX_HZ = 72_000_000
AD9102_NYQUIST_HZ = AD9102_DAC_CLK_HZ // 2

CTRL = 0x00
STATUS = 0x04
SPI_ADDR = 0x08
SPI_WDATA = 0x0C
SPI_RDATA = 0x10
SPI_DIV = 0x14
GPIO_CTRL = 0x18
DAC_CLK_HZ = 0x1C
VERSION = 0x20
COMMAND_COUNT = 0x24
ERROR_COUNT = 0x28

STATUS_BUSY = 1 << 2
STATUS_DONE = 1 << 3

REG_SPICONFIG = 0x0000
REG_DACDOF = 0x0025
REG_RAMUPDATE = 0x001D
REG_PAT_STATUS = 0x001E
REG_PAT_TYPE = 0x001F
REG_WAV_CONFIG = 0x0027
REG_PAT_TIMEBASE = 0x0028
REG_PAT_PERIOD = 0x0029
REG_DAC_DGAIN = 0x0035
REG_DDS_TW32 = 0x003E
REG_DDS_TW1 = 0x003F
REG_DDS_PW = 0x0043
REG_DDS_CONFIG = 0x0045
REG_TW_RAM_CONFIG = 0x0047
REG_START_DLY = 0x005C
REG_START_ADDR = 0x005D
REG_STOP_ADDR = 0x005E
REG_SRAM_DATA = 0x6000

WAV_CONFIG_DDS_CONTINUOUS = 0x0031
WAV_CONFIG_WAVE_RAM = 0x0000

SRAM_SETUP_REGISTERS = (
    (0x0000, 0x0000), (0x0001, 0x0E00), (0x0002, 0x0000),
    (0x0003, 0x0000), (0x0004, 0x0000), (0x0005, 0x0000),
    (0x0006, 0x0000), (0x0007, 0x4000), (0x0008, 0x0000),
    (0x0009, 0x0000), (0x000A, 0x0000), (0x000B, 0x0000),
    (0x000C, 0x1F00), (0x000D, 0x0000), (0x000E, 0x0000),
    (0x001F, 0x0000), (0x0020, 0x000E), (0x0022, 0x0000),
    (0x0023, 0x0000), (0x0024, 0x0000), (0x0025, 0x0000),
    (0x0026, 0x0000), (0x0027, 0x3030), (0x0028, 0x0111),
    (0x0029, 0xFFFF), (0x002A, 0x0000), (0x002B, 0x0101),
    (0x002C, 0x0003), (0x002D, 0x0000), (0x002E, 0x0000),
    (0x002F, 0x0000), (0x0030, 0x0000), (0x0031, 0x0000),
    (0x0032, 0x0000), (0x0033, 0x0000), (0x0034, 0x0000),
    (0x0035, 0x4000), (0x0036, 0x0000), (0x0037, 0x0200),
    (0x003E, 0x0000), (0x003F, 0x0000), (0x0040, 0x0000),
    (0x0041, 0x0000), (0x0042, 0x0000), (0x0043, 0x0000),
    (0x0044, 0x0000), (0x0045, 0x0000), (0x0047, 0x0000),
    (0x0050, 0x0000), (0x0051, 0x0000), (0x0052, 0x0000),
    (0x0053, 0x0000), (0x0054, 0x0000), (0x0055, 0x0000),
    (0x0056, 0x0000), (0x0057, 0x0000), (0x0058, 0x0000),
    (0x0059, 0x0000), (0x005A, 0x0000), (0x005B, 0x0000),
    (0x005C, 0x0FA0), (0x005D, 0x0000), (0x005E, 0x3FF0),
    (0x005F, 0x0100), (0x001E, 0x0001), (0x001D, 0x0001),
)


class AD9102:
    def __init__(self, base_addr=AD9102_BASE, spi_div=7, timeout=0.1):
        self.mmio = MMIO(base_addr, AD9102_RANGE)
        self.timeout = float(timeout)
        self.mmio.write(SPI_DIV, int(spi_div) & 0xFFFF)
        self.mmio.write(GPIO_CTRL, 0b11)

        version = self.mmio.read(VERSION)
        dac_clock = self.mmio.read(DAC_CLK_HZ)
        if version != 0xAD910201:
            raise RuntimeError("Unexpected AD9102 PL IP version 0x%08X" % version)
        if dac_clock != AD9102_DAC_CLK_HZ:
            raise RuntimeError("Unexpected AD9102 DAC clock %d Hz" % dac_clock)

    def _wait_idle(self):
        deadline = monotonic() + self.timeout
        while self.mmio.read(STATUS) & STATUS_BUSY:
            if monotonic() >= deadline:
                raise TimeoutError("AD9102 PL SPI transaction timed out")

    def write_reg(self, address, value):
        self._wait_idle()
        self.mmio.write(SPI_ADDR, int(address) & 0x7FFF)
        self.mmio.write(SPI_WDATA, int(value) & 0xFFFF)
        self.mmio.write(CTRL, 0x1)
        self._wait_idle()

    def read_reg(self, address):
        self._wait_idle()
        self.mmio.write(SPI_ADDR, int(address) & 0x7FFF)
        self.mmio.write(SPI_WDATA, 0)
        self.mmio.write(CTRL, 0x3)
        self._wait_idle()
        return self.mmio.read(SPI_RDATA) & 0xFFFF

    def reset(self):
        self.stop()
        self.mmio.write(GPIO_CTRL, 0b01)
        sleep(0.002)
        self.mmio.write(GPIO_CTRL, 0b11)
        sleep(0.010)

    def stop(self):
        self.mmio.write(GPIO_CTRL, 0b11)

    def start(self):
        self.mmio.write(GPIO_CTRL, 0b10)

    def ram_update(self):
        self.write_reg(REG_RAMUPDATE, 0x0001)

    @staticmethod
    def frequency_to_ftw(freq_hz, allow_above_recommended=False):
        freq_hz = int(freq_hz)
        limit = AD9102_NYQUIST_HZ - 1
        if not allow_above_recommended:
            limit = AD9102_RECOMMENDED_MAX_HZ
        if not 1 <= freq_hz <= limit:
            raise ValueError("frequency must be 1..%d Hz" % limit)
        return (
            (freq_hz << 24) + (AD9102_DAC_CLK_HZ // 2)
        ) // AD9102_DAC_CLK_HZ

    @staticmethod
    def ftw_to_frequency(ftw):
        return (
            (int(ftw) & 0xFFFFFF) * AD9102_DAC_CLK_HZ
        ) / float(1 << 24)

    def set_frequency(self, freq_hz, update=True, allow_above_recommended=False):
        ftw = self.frequency_to_ftw(freq_hz, allow_above_recommended)
        self.write_reg(REG_DDS_TW32, (ftw >> 8) & 0xFFFF)
        self.write_reg(REG_DDS_TW1, (ftw & 0xFF) << 8)
        self.write_reg(REG_DDS_PW, 0x0000)
        if update:
            self.ram_update()
        return ftw, self.ftw_to_frequency(ftw)

    def set_amplitude(self, amplitude, update=True):
        amplitude = int(amplitude)
        if not 0 <= amplitude <= 0x7FF:
            raise ValueError("amplitude must be 0..0x7FF")
        self.write_reg(REG_DAC_DGAIN, (amplitude & 0x0FFF) << 4)
        if update:
            self.ram_update()
        return amplitude

    def configure_sine(
        self, freq_hz, amplitude=0x400, allow_above_recommended=False
    ):
        self.stop()
        self.write_reg(REG_PAT_STATUS, 0x0000)
        self.write_reg(REG_DACDOF, 0x0000)
        self.set_amplitude(amplitude, update=False)
        ftw, actual_hz = self.set_frequency(
            freq_hz,
            update=False,
            allow_above_recommended=allow_above_recommended,
        )
        self.write_reg(REG_DDS_CONFIG, 0x0000)
        self.write_reg(REG_TW_RAM_CONFIG, 0x0000)
        self.write_reg(REG_WAV_CONFIG, WAV_CONFIG_DDS_CONTINUOUS)
        self.write_reg(REG_PAT_STATUS, 0x0001)
        self.ram_update()
        self.start()
        return {
            "mode": "sine",
            "requested_hz": int(freq_hz),
            "actual_hz": actual_hz,
            "ftw": ftw,
            "amplitude": int(amplitude),
        }

    @staticmethod
    def _encode_sram_sample(sample):
        sample = int(sample)
        if not -2048 <= sample <= 2047:
            raise ValueError("SRAM samples must be signed 12-bit values")
        return (sample << 2) & 0xFFFF

    def load_arbitrary(self, samples, amplitude=0x400, progress=None):
        samples = [int(value) for value in samples]
        count = len(samples)
        if not 2 <= count <= 4096:
            raise ValueError("arbitrary waveform must contain 2..4096 samples")

        self.stop()
        for address, value in (
            (REG_PAT_STATUS, 0x0000),
            (REG_WAV_CONFIG, 0x0000),
            (REG_DDS_CONFIG, 0x0000),
            (REG_TW_RAM_CONFIG, 0x0000),
            (REG_PAT_TYPE, 0x0000),
            (REG_PAT_TIMEBASE, 0x0000),
            (REG_PAT_PERIOD, 0x0000),
            (REG_START_DLY, 0x0000),
            (REG_START_ADDR, 0x0000),
            (REG_STOP_ADDR, 0x0000),
        ):
            self.write_reg(address, value)
        self.ram_update()

        self.write_reg(REG_PAT_STATUS, 0x0004)
        for index, sample in enumerate(samples):
            self.write_reg(
                REG_SRAM_DATA + index,
                self._encode_sram_sample(sample),
            )
            if progress is not None and (
                index == 0 or index + 1 == count or (index + 1) % 256 == 0
            ):
                progress(index + 1, count)
        self.write_reg(REG_PAT_STATUS, 0x0000)

        for address, value in SRAM_SETUP_REGISTERS:
            self.write_reg(address, value)

        self.set_amplitude(amplitude, update=False)
        self.write_reg(REG_PAT_PERIOD, count - 1)
        self.write_reg(REG_START_DLY, 0x0000)
        self.write_reg(REG_START_ADDR, 0x0000)
        self.write_reg(REG_STOP_ADDR, (count - 1) << 4)
        self.write_reg(REG_DDS_CONFIG, 0x0000)
        self.write_reg(REG_TW_RAM_CONFIG, 0x0000)
        self.write_reg(REG_WAV_CONFIG, WAV_CONFIG_WAVE_RAM)
        self.write_reg(REG_PAT_STATUS, 0x0001)
        self.ram_update()
        self.start()

        actual_hz = AD9102_DAC_CLK_HZ / float(count)
        return {
            "mode": "arbitrary",
            "samples": count,
            "actual_hz": actual_hz,
            "amplitude": int(amplitude),
        }

    def configure_arbitrary(
        self, samples, freq_hz, amplitude=0x400, progress=None
    ):
        source = [int(value) for value in samples]
        if len(source) < 2:
            raise ValueError("source waveform must contain at least 2 samples")
        if any(value < -2048 or value > 2047 for value in source):
            raise ValueError("source samples must be signed 12-bit values")

        freq_hz = float(freq_hz)
        if freq_hz <= 0:
            raise ValueError("frequency must be positive")
        output_count = int(round(AD9102_DAC_CLK_HZ / freq_hz))
        if not 2 <= output_count <= 4096:
            raise ValueError(
                "SRAM waveform frequency must be %.3f..%.3f Hz"
                % (
                    AD9102_DAC_CLK_HZ / 4096.0,
                    AD9102_DAC_CLK_HZ / 2.0,
                )
            )

        source_count = len(source)
        resampled = []
        for index in range(output_count):
            position = index * source_count / float(output_count)
            left = int(position) % source_count
            right = (left + 1) % source_count
            fraction = position - int(position)
            value = round(
                source[left] * (1.0 - fraction) + source[right] * fraction
            )
            resampled.append(max(-2048, min(2047, int(value))))

        result = self.load_arbitrary(
            resampled, amplitude=amplitude, progress=progress
        )
        result["requested_hz"] = freq_hz
        result["source_samples"] = source_count
        return result

    def initialize(self, freq_hz=1_000, amplitude=0x400):
        self.reset()
        spi_config = self.read_reg(REG_SPICONFIG)
        result = self.configure_sine(freq_hz, amplitude)
        result["spi_config"] = spi_config
        return result

    def status(self):
        status = self.mmio.read(STATUS)
        return {
            "raw": status,
            "busy": bool(status & STATUS_BUSY),
            "done": bool(status & STATUS_DONE),
            "trigger_n": bool(status & (1 << 5)),
            "reset_n": bool(status & (1 << 6)),
            "clk_cmos_sample": bool(status & (1 << 7)),
            "commands": self.mmio.read(COMMAND_COUNT),
            "errors": self.mmio.read(ERROR_COUNT),
        }
