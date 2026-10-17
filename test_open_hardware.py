import serial
import serial.tools.list_ports
import time
import sys

def find_tang_port():
    ports = list(serial.tools.list_ports.comports())
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

    send_line(ser, "", 0.3)
    send_line(ser, "NEW", 0.3)

    with open("naam_sd_demo.bas", "r") as f:
        lines = [l.strip() for l in f if l.strip()]

    print("\n--- STAP 1: naam_sd_demo.bas invoeren in BBC BASIC ---")
    for l in lines:
        send_line(ser, l, 0.2)

    print("\n--- STAP 2: Demo-programma opslaan op SD-kaart als \"NAAMDEMO\" ---")
    send_line(ser, 'SAVE "NAAMDEMO"', 1.5)

    print("\n--- STAP 3: Uitvoeren met RUN en naam \"ROB\" invoeren ---")
    send_line(ser, 'RUN', 0.8)
    out_run = send_line(ser, 'ROB', 2.0)

    print("\n--- STAP 4: *CAT controleren (zowel NAAMDEMO als NAAM.DAT staan op SD!) ---")
    out_cat = send_line(ser, '*CAT', 1.0)

    ser.close()

    if "WELKOM TERUG VANAF SD-KAART, ROB!" in out_run:
        print("\n============================================================")
        print("  OPENOUT / PRINT# / CLOSE# / OPENIN / INPUT# 100% GELUKT!  ")
        print("============================================================")
    else:
        print("\n[!] Let op: Controleer bovenstaande output.")

if __name__ == "__main__":
    main()
