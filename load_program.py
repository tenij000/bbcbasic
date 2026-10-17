import serial
import serial.tools.list_ports
import sys
import time
import os

print("--- BBC BASIC Programma Loader ---")

# Vraag om bestandsnaam
filename = input("Geef de naam van het bestand (bijv. mijn_game.bas): ")
if not filename.endswith(".bas") and not os.path.exists(filename):
    filename += ".bas"

if not os.path.exists(filename):
    print(f"Fout: Bestand '{filename}' niet gevonden!")
    sys.exit(1)

# Zoek alle beschikbare COM poorten
ports = list(serial.tools.list_ports.comports())

if not ports:
    print("Geen COM poorten gevonden! Controleer of je FPGA is aangesloten.")
    sys.exit(1)

print("\nBeschikbare COM poorten:")
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
    print(f"\nVerbonden met {COM_PORT}.")
    
    # Maak de buffer leeg voor de zekerheid
    ser.reset_input_buffer()

    print(f"Bestand '{filename}' inladen...")
    
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    for idx, line in enumerate(lines):
        line = line.strip()
        if not line:
            continue
            
        # Stuur regel naar de FPGA (met Carriage Return)
        ser.write(line.encode('ascii', errors='ignore') + b'\r')
        
        # Wacht heel even zodat BBC BASIC de regel kan parsen
        # Als we te snel sturen, mist de 6502 karakters!
        time.sleep(0.05) 
        
        sys.stdout.write(f"\rRegel {idx+1}/{len(lines)} verzonden...")
        sys.stdout.flush()

    print("\n\nKlaar! Typ 'RUN' of 'LIST' in je terminal om het te bekijken.")

except serial.SerialException as e:
    print(f"\nFout bij openen of gebruiken van poort {COM_PORT}: {e}")
except Exception as e:
    print(f"\nOnverwachte fout: {e}")
finally:
    if 'ser' in locals() and ser.is_open:
        ser.close()
