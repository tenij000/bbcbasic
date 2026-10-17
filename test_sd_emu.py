from py65.devices.mpu6502 import MPU
from py65.memory import ObservableMemory

def run_test(simulate_sdhc=True):
    rom = open('BBCBasicSBC02/build/SBC02', 'rb').read()
    mpu = MPU()
    mem = ObservableMemory()
    mem[0xB800:0x10000] = list(rom)

    # Emulate both FPGA-Disk ($A012-$A014) and SDHC card over SPI ($A010-$A011)
    ramdisk = bytearray(16384)
    sd_sectors = {}
    rd_lo = [0]
    rd_hi = [0]

    def wr_lo(addr, val): rd_lo[0] = val
    def wr_hi(addr, val): rd_hi[0] = val
    def wr_dat(addr, val): ramdisk[((rd_hi[0] & 0x3F) << 8) | rd_lo[0]] = val
    def rd_dat(addr): return ramdisk[((rd_hi[0] & 0x3F) << 8) | rd_lo[0]]

    # Simple SPI SDHC state machine for testing
    spi_rx_queue = []
    spi_cmd_buf = []
    spi_write_state = [0] # 0=idle, 1=waiting_fe, 2=reading_512
    spi_write_sec = [0]
    spi_write_buf = []

    def wr_spi(addr, val):
        if not simulate_sdhc:
            spi_rx_queue.append(0xFF)
            return
        if spi_write_state[0] == 1:
            spi_rx_queue.append(0xFF)
            if val == 0xFE:
                spi_write_state[0] = 2
                spi_write_buf.clear()
            return
        elif spi_write_state[0] == 2:
            spi_write_buf.append(val)
            if len(spi_write_buf) == 512:
                sd_sectors[spi_write_sec[0]] = bytes(spi_write_buf)
                spi_rx_queue.extend([0xFF, 0xFF, 0xFF, 0x05, 0x00, 0xFF])
                spi_write_state[0] = 0
            else:
                spi_rx_queue.append(0xFF)
            return

        if len(spi_cmd_buf) == 0 and (val & 0xC0) == 0x40 and val != 0xFF:
            spi_cmd_buf.append(val)
            spi_rx_queue.append(0xFF)
        elif len(spi_cmd_buf) > 0:
            spi_cmd_buf.append(val)
            if len(spi_cmd_buf) < 6:
                spi_rx_queue.append(0xFF)
            else:
                cmd = spi_cmd_buf[0]
                arg = (spi_cmd_buf[1]<<24)|(spi_cmd_buf[2]<<16)|(spi_cmd_buf[3]<<8)|spi_cmd_buf[4]
                spi_cmd_buf.clear()
                spi_rx_queue.append(0xFF)
                if cmd == 0x40:   # CMD0
                    spi_rx_queue.append(0x01)
                elif cmd == 0x48: # CMD8
                    spi_rx_queue.extend([0x01, 0x00, 0x00, 0x01, 0xAA])
                elif cmd == 0x77: # CMD55
                    spi_rx_queue.append(0x01)
                elif cmd == 0x69: # ACMD41
                    spi_rx_queue.append(0x00)
                elif cmd == 0x7A: # CMD58
                    spi_rx_queue.extend([0x00, 0x40, 0xFF, 0x80, 0x00])
                elif cmd == 0x51: # CMD17 Read Block
                    sec_data = sd_sectors.get(arg, bytes(512))
                    spi_rx_queue.extend([0x00, 0xFF, 0xFE] + list(sec_data) + [0xFF, 0xFF])
                elif cmd == 0x58: # CMD24 Write Block
                    spi_write_sec[0] = arg
                    spi_write_state[0] = 1
                    spi_rx_queue.append(0x00)
        else:
            if not spi_rx_queue:
                spi_rx_queue.append(0xFF)

    def rd_spi(addr):
        if spi_rx_queue:
            return spi_rx_queue.pop(0)
        return 0xFF

    mem.subscribe_to_write([0xA012], wr_lo)
    mem.subscribe_to_write([0xA013], wr_hi)
    mem.subscribe_to_write([0xA014], wr_dat)
    mem.subscribe_to_read([0xA014], rd_dat)
    mem.subscribe_to_write([0xA010], wr_spi)
    mem.subscribe_to_read([0xA010], rd_spi)

    mpu.memory = mem
    mpu.pc = mem[0xFFFC] | (mem[0xFFFD] << 8)

    script = (
        b'10 PRINT "HALLO VANAF SD KAART!"\r'
        b'20 FOR I=1 TO 3: PRINT "TELLER=";I: NEXT I\r'
        b'SAVE "DEMOPROG"\r'
        b'*CAT\r'
        b'NEW\r'
        b'PRINT "NA NEW GEHEUGEN LEEG:"\r'
        b'LIST\r'
        b'LOAD "DEMOPROG"\r'
        b'LIST\r'
        b'RUN\r'
    )
    in_buf = list(script)
    out_chars = []

    def pop():
        mpu.sp = (mpu.sp + 1) & 0xFF
        return mem[0x100 + mpu.sp]

    for _ in range(1000000):
        pc = mpu.pc
        if pc == 0xFFE0:
            if in_buf:
                mpu.a = in_buf.pop(0)
                mpu.p &= ~0x01
                addr = pop() | (pop() << 8)
                mpu.pc = addr + 1
                continue
            else:
                break
        elif pc == 0xFFEE:
            out_chars.append(chr(mpu.a) if 32 <= mpu.a < 127 or mpu.a in (10,13) else '')
            addr = pop() | (pop() << 8)
            mpu.pc = addr + 1
            continue
        mpu.step()

    print("=== TEST SDHC =", simulate_sdhc, "===")
    print(''.join(out_chars))

if __name__ == '__main__':
    run_test(simulate_sdhc=True)
    run_test(simulate_sdhc=False)
