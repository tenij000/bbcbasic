import serial
import serial.tools.list_ports
import sys
import time

print("--- FPGA Scherm Wisser ---")

# Zoek alle beschikbare COM poorten
ports = list(serial.tools.list_ports.comports())

if not ports:
    print("Geen COM poorten gevonden!")
    sys.exit(1)

print("Beschikbare COM poorten:")
for i, port in enumerate(ports):
    print(f"[{i}] {port.device} - {port.description}")

try:
    keuze = int(input("\nKies het nummer van de COM poort: "))
    if keuze < 0 or keuze >= len(ports):
        print("Ongeldige keuze.")
        sys.exit(1)
except ValueError:
    print("Ongeldige invoer.")
    sys.exit(1)

COM_PORT = ports[keuze].device

try:
    ser = serial.Serial(COM_PORT, 115200, timeout=1)
    print(f"\nVerbonden met {COM_PORT}.")
    
    print("Stuur magie (Image Mode)...")
    ser.write(b'\x1BIMG')
    time.sleep(0.1)
    
    print("Stuur een zwart scherm (dit duurt ca 16 seconden)...")
    
    # Een zwart scherm op 1280x720 = 921600 pixels = 1843200 bytes (RGB565)
    # Zwart is 0x0000 in RGB565
    chunk = b'\x00\x00' * 1280
    for y in range(720):
        ser.write(chunk)
        if y % 72 == 0:
            print(f"Voortgang: {y//7}%")
            
    print("Voortgang: 100%")
    
    print("Stuur magie (Text Mode)...")
    ser.write(b'\x1BTXT')
    
    print("Scherm is gewist!")
    
except Exception as e:
    print(f"Fout: {e}")
