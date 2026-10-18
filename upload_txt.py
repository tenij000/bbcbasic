import serial
import time

README_TXT = (
    "=== WELKOM OP DE 6502 + MINIGPU ===\r"
    "Voorbeelden van SD-MOS 1.30:\r"
    " *BG ON / OFF -> 16 Sprites Multitask!\r"
    " *INFO        -> Toon bestandsgroottes\r"
    " *DRIVE 1     -> Ga naar ASM Floppy D1\r"
    " *RUN CHESS   -> Start 1976 MicroChess\r"
    " *DUMP B000   -> Bekijk ROM in HEX"
)

COMMANDS_TXT = (
    "=== MULTITASKING & BESTANDEN ===\r"
    " 1. Multitask: *BG ON / *BG OFF\r"
    " 2. Klok (100Hz): PRINT TIME\r"
    " 3. Hernoem/Wis: *RENAME / *DELETE\r"
    " 4. Kopieer: *COPY SDTEST (SD<->SDRAM)\r"
    " 5. Lees tekst: *TYPE README.TXT"
)

def write_text_file_to_sd(s, filename, content, drive=0):
    raw = content.encode('ascii')
    assert len(raw) <= 255, f"Te lang ({len(raw)} bytes > 255)"
    print(f"Schrijven van {filename} ({len(raw)} bytes) naar Drive {drive}...")

    s.write(f"*SD\r".encode('ascii'))
    time.sleep(0.5)
    s.read_all()

    s.write(f"*DRIVE {drive}\r".encode('ascii'))
    time.sleep(0.6)
    s.read_all()

    # Open bestand met OPENOUT en schrijf ruwe ASCII bytes via BPUT#
    s.write(f'F%=OPENOUT("{filename}")\r'.encode('ascii'))
    time.sleep(0.3)
    s.read_all()

    chunk_size = 8
    for i in range(0, len(raw), chunk_size):
        chunk = raw[i:i+chunk_size]
        cmd = ":".join(f"BPUT#F%,{b}" for b in chunk) + "\r"
        s.write(cmd.encode('ascii'))
        time.sleep(0.04)
        s.read_all()

    s.write(b"CLOSE#F%\r")
    time.sleep(1.2)
    print(s.read_all().decode('ascii', errors='replace').strip())

if __name__ == '__main__':
    s = serial.Serial('COM6', 115200, timeout=1)
    s.write(b'\x1b\r')
    time.sleep(0.2)
    s.read_all()

    for drv in (0, 1):
        write_text_file_to_sd(s, "README.TXT", README_TXT, drv)
        write_text_file_to_sd(s, "COMMANDS.TXT", COMMANDS_TXT, drv)

    print("\n--- Live test op Drive 0 ---")
    for cmd in ['*DRIVE 0', '*INFO', '*TYPE README.TXT', '*TYPE COMMANDS.TXT']:
        s.write((cmd + '\r').encode('ascii'))
        time.sleep(0.7)
        print(s.read_all().decode('ascii', errors='replace'), end='')

    s.close()
