import serial
import serial.tools.list_ports
import time
import sys

# Zoek alle beschikbare COM poorten
ports = list(serial.tools.list_ports.comports())

if not ports:
    print("Geen COM poorten gevonden! Controleer of je FPGA is aangesloten.")
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
    print("Ongeldige invoer, vul een nummer in.")
    sys.exit(1)

COM_PORT = ports[keuze].device

try:
    ser = serial.Serial(COM_PORT, 115200, timeout=1)
    print(f"\nVerbonden met {COM_PORT} - Retro Terminal Mode!")
    print("Typ je bericht en druk op Enter (of typ 'quit' om af te sluiten):")
    
    while True:
        text = input("> ")
        if text.lower() == 'quit':
            break
        
        # We voegen een newline character toe zodat de cursor naar beneden gaat
        text += '\n'
        
        # Stuur de karakters een voor een
        for char in text:
            ser.write(char.encode('ascii', errors='ignore'))
            # Klein wachtmomentje voor de zekerheid
            time.sleep(0.001)

except serial.SerialException as e:
    print(f"Fout bij openen van {COM_PORT}: {e}")
    print("Controleer of de poort klopt en niet al open staat in een ander programma.")
