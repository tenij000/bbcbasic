import serial
import serial.tools.list_ports
import sys
import time

print("--- BBC BASIC Programma Saver ---")

# Vraag om bestandsnaam
filename = input("Geef de naam voor het bestand (bijv. mijn_game.bas): ")
if not filename:
    filename = "programma.bas"
if not filename.endswith(".bas"):
    filename += ".bas"

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

    print("Stuur 'LIST' commando naar de FPGA...")
    ser.write(b'LIST\r')
    
    print("Wachten op output... (dit kan even duren bij een groot programma)")
    
    captured_lines = []
    
    # We lezen karakter voor karakter om de prompt '>' te detecteren
    current_line = ""
    start_time = time.time()
    
    while True:
        # Lees 1 byte
        char = ser.read(1)
        
        if not char:
            # Timeout (geen data meer ontvangen)
            if time.time() - start_time > 2.0:
                print("\nTimeout: Geen data meer ontvangen van de FPGA.")
                break
            continue
            
        # Reset timeout
        start_time = time.time()
        
        try:
            c = char.decode('ascii', errors='ignore')
        except:
            continue
            
        # Als we het prompt karakter '>' aan het begin van een nieuwe regel zien, zijn we klaar!
        if c == '>' and current_line.strip() == "":
            break
            
        if c == '\n' or c == '\r':
            if current_line.strip():
                # Negeer de echo van het "LIST" commando zelf
                if current_line.strip() != "LIST":
                    captured_lines.append(current_line.strip())
                    sys.stdout.write(".")
                    sys.stdout.flush()
            current_line = ""
        else:
            # Negeer verborgen karakters en backspaces
            if ord(c) >= 32 and ord(c) < 127:
                current_line += c

    print("\n\nKlaar met uitlezen!")
    
    if captured_lines:
        with open(filename, 'w', encoding='utf-8') as f:
            for line in captured_lines:
                f.write(line + '\n')
        print(f"Succes! Programma met {len(captured_lines)} regels is opgeslagen in '{filename}'.")
    else:
        print("Geen programma gevonden! Had je wel regels in het geheugen staan?")

except serial.SerialException as e:
    print(f"\nFout bij openen of gebruiken van poort {COM_PORT}: {e}")
except Exception as e:
    print(f"\nOnverwachte fout: {e}")
finally:
    if 'ser' in locals() and ser.is_open:
        ser.close()
