import serial
import serial.tools.list_ports
import sys
import msvcrt
import time

print("--- FPGA Typemachine ---")

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
    print(f"\nVerbonden met {COM_PORT}.")
    
    # Stuur commando om FPGA naar Tekst/Terminal modus te schakelen
    # ESC T X T
    print("Schakelen naar tekst-modus op de FPGA...")
    ser.write(b'\x1BTXT')
    time.sleep(0.1)

    print("\n" + "="*40)
    print("Je kunt nu typen! Alles wat je typt verschijnt direct op je beeldscherm.")
    print("Druk op 'ESC' om dit script te stoppen.")
    print("="*40 + "\n")

    while True:
        if msvcrt.kbhit():
            key = msvcrt.getch()
            
            # Controleer op ESC (ASCII 27) om te stoppen
            if key == b'\x1b':
                print("\nGestopt door gebruiker.")
                break
                
            # Stuur het ingetoetste karakter direct naar de FPGA
            ser.write(key)
            
            # Print het ook in de lokale terminal
            if key == b'\r':
                print()
            elif key == b'\x08':
                sys.stdout.write('\b \b')
                sys.stdout.flush()
            else:
                try:
                    sys.stdout.write(key.decode('utf-8', errors='ignore'))
                    sys.stdout.flush()
                except:
                    pass
                    
except serial.SerialException as e:
    print(f"\nFout bij openen of gebruiken van poort {COM_PORT}: {e}")
except KeyboardInterrupt:
    print("\nGestopt.")
    sys.exit(0)
