import serial
import serial.tools.list_ports
import time
import sys

def find_tang_port():
    ports = list(serial.tools.list_ports.comports())
    # Prefer COM6 or higher port numbers typical for Tang Nano 20K UART
    for p in sorted(ports, key=lambda x: x.device, reverse=True):
        if "USB" in p.description.upper() or "SERIAL" in p.description.upper() or "COM" in p.device.upper():
            return p.device
    return "COM6"

def send_line(ser, line, wait_s=0.35):
    print(f">>> {line}")
    for ch in line:
        ser.write(ch.encode('ascii'))
        time.sleep(0.008)
    ser.write(b'\r')
    time.sleep(wait_s)
    out = b""
    while ser.in_waiting:
        out += ser.read(ser.in_waiting)
        time.sleep(0.05)
    text = out.decode('ascii', errors='ignore')
    if text.strip():
        print(text)
    return text

def main():
    port = sys.argv[1] if len(sys.argv) > 1 else find_tang_port()
    print(f"[*] Verbinden met Tang Nano 20K op {port} (115200 baud)...")
    ser = serial.Serial(port, 115200, timeout=0.5)
    time.sleep(0.5)
    ser.reset_input_buffer()

    # Ensure we are in BBC BASIC prompt
    send_line(ser, "", 0.3)
    send_line(ser, "NEW", 0.3)

    # Read test program from sd_test.bas
    with open("sd_test.bas", "r") as f:
        lines = [l.strip() for l in f if l.strip()]

    print("\n--- STAP 1: Testprogramma invoeren in BBC BASIC ---")
    for l in lines:
        send_line(ser, l, 0.2)

    print("\n--- STAP 2: Opslaan met SAVE \"SDTEST\" ---")
    out_save = send_line(ser, 'SAVE "SDTEST"', 1.5)

    print("\n--- STAP 3: Catalogus opvragen met *CAT ---")
    out_cat = send_line(ser, '*CAT', 1.0)

    print("\n--- STAP 4: Geheugen wissen met NEW (en controleren met LIST) ---")
    send_line(ser, 'NEW', 0.3)
    out_empty = send_line(ser, 'LIST', 0.4)

    print("\n--- STAP 5: Terugladen vanaf opslag met LOAD \"SDTEST\" ---")
    out_load = send_line(ser, 'LOAD "SDTEST"', 1.5)

    print("\n--- STAP 6: Geladen programma bekijken met LIST ---")
    out_list = send_line(ser, 'LIST', 0.8)

    print("\n--- STAP 7: Geladen programma uitvoeren met RUN ---")
    out_run = send_line(ser, 'RUN', 1.5)

    ser.close()

    if "OPGESLAGEN:" in out_save and "INGELADEN:" in out_load and "6502 ROCKS!" in out_run:
        print("\n=======================================================")
        print("  HARDWARE SD-MOS SAVE & LOAD TEST 100% GESLAAGD!  ")
        print("=======================================================")
    else:
        print("\n[!] Let op: Controleer bovenstaande output.")

if __name__ == "__main__":
    main()
