import serial
import serial.tools.list_ports
import time
import sys
import random

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
    print(f"\nVerbonden met {COM_PORT} - Frame Buffer Mode!")
    
    # Stuur een sync byte om de FPGA state machine te resetten
    ser.write(b'\xFF')
    time.sleep(0.1)
    
    def rgb_to_8bit(r, g, b):
        """Converteert 0-255 RGB naar RRRGGGBB (3:3:2) formaat"""
        r_3bit = (r >> 5) & 0x07
        g_3bit = (g >> 5) & 0x07
        b_2bit = (b >> 6) & 0x03
        color = (r_3bit << 5) | (g_3bit << 2) | b_2bit
        if color == 0xFF:
            return 0xFE
        return color

    def draw_pixel(x, y, color_8bit):
        """Stuurt 3 bytes: X, Y, Color"""
        if x < 0 or x > 159 or y < 0 or y > 89:
            return
        ser.write(bytes([x, y, color_8bit]))
        # time.sleep(0.0001)

    print("Tekenen we een rode pixel in het midden...")
    draw_pixel(80, 45, rgb_to_8bit(255, 0, 0))
    time.sleep(1)

    print("Tekenen we een blauw vierkant...")
    for y in range(20, 40):
        for x in range(20, 40):
            draw_pixel(x, y, rgb_to_8bit(0, 0, 255))
            
    print("En nu wat random pixels (druk op Ctrl+C om te stoppen)...")
    while True:
        x = random.randint(0, 159)
        y = random.randint(0, 89)
        # Random felle kleuren
        c = random.randint(1, 254) 
        draw_pixel(x, y, c)

except serial.SerialException as e:
    print(f"Fout bij openen van {COM_PORT}: {e}")
except KeyboardInterrupt:
    print("\nKlaar met tekenen!")
