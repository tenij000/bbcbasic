import serial
import serial.tools.list_ports
import time
import sys

print("--- FPGA Cirkel Tekenaar ---")

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
    print(f"\nVerbonden met {COM_PORT}. Zorg dat BBC BASIC draait op de FPGA!")
    
    # Korte pauze voor verbinding
    time.sleep(0.5)

    while True:
        print("\n" + "="*40)
        print("Teken een cirkel!")
        print("Laat een veld leeg en druk op Enter om te stoppen.")
        print("="*40)
        
        in_x = input("Middelpunt X (bijv. 640): ")
        if not in_x: break
            
        in_y = input("Middelpunt Y (bijv. 512): ")
        if not in_y: break
            
        in_r = input("Straal (Radius) (bijv. 300): ")
        if not in_r: break
        
        try:
            x = int(in_x)
            y = int(in_y)
            r = int(in_r)
        except ValueError:
            print("Vul a.u.b. geldige getallen in!")
            continue
            
        # Bereken het rand-punt voor BBC BASIC
        plot_x = x + r
        plot_y = y
        
        # Maak de BBC BASIC commando string
        # We voegen ook een MODE 0 en GCOL toe zodat we zeker weten dat het zichtbaar is.
        # \r is de Enter toets voor BBC BASIC.
        command = f'MODE 0: GCOL 0, 1: MOVE {x},{y}: PLOT 145, {plot_x},{plot_y}\r'
        
        print(f"\nStuur commando naar FPGA: {command.strip()}")
        
        # Stuur het naar de FPGA (alsof we het razendsnel typen)
        ser.write(command.encode('ascii'))
        
        # Wacht heel even zodat BBC BASIC het kan verwerken
        time.sleep(0.5)
        
    print("\nGestopt door gebruiker.")
    
except serial.SerialException as e:
    print(f"\nFout bij openen of gebruiken van poort {COM_PORT}: {e}")
except KeyboardInterrupt:
    print("\nGestopt.")
    sys.exit(0)
