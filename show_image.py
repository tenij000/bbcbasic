import serial
import serial.tools.list_ports
import time
import sys
try:
    from PIL import Image
except ImportError:
    print("De 'Pillow' library is niet gevonden. Installeer deze via:")
    print("pip install pillow")
    sys.exit(1)

# Configuratie
IMAGE_FILE = 'boerderij.jpg'  # Vul hier je bestand in (of laat het script deze zoeken)

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

def rgb_to_8bit(r, g, b):
    """Converteert 0-255 RGB naar RRRGGGBB (3:3:2) formaat"""
    r_3bit = (r >> 5) & 0x07
    g_3bit = (g >> 5) & 0x07
    b_2bit = (b >> 6) & 0x03
    color = (r_3bit << 5) | (g_3bit << 2) | b_2bit
    if color == 0xFF:
        return 0xFE # Voorkom dat wit (0xFF) als sync byte wordt gezien
    return color

try:
    print(f"\nAfbeelding {IMAGE_FILE} inladen...")
    img = Image.open(IMAGE_FILE)
    # Verklein naar 640x360 voor de SDRAM resolutie!
    img = img.resize((640, 360), Image.Resampling.LANCZOS)
    img = img.convert('RGB')
    
    # 2Mbaud or 115200. Let's start safe with 115200, though 2000000 works on Nano 20K UART.
    # The user can bump it if they want.
    ser = serial.Serial(COM_PORT, 115200, timeout=1)
    print(f"Verbonden met {COM_PORT}. Afbeelding wordt verzonden...")
    
    ser.write(b'\0\0\0\0\0\0') # Flush eventuele ruis
    time.sleep(0.5)
    ser.write(b'\x1BIMG')
    time.sleep(0.1)
    
    pixels = img.load()
    
    pixel_data = bytearray()
    for y in range(360):
        for x in range(640):
            r, g, b = pixels[x, y]
            color_8bit = rgb_to_8bit(r, g, b)
            pixel_data.append(color_8bit)
            
    print(f"Verzenden van {len(pixel_data)} bytes...")
    
    # Send row by row to prevent CH340 buffer overflow on Windows
    # 1 row = 640 bytes.
    row_size = 640
    for y in range(360):
        row_data = pixel_data[y*row_size : (y+1)*row_size]
        ser.write(row_data)
        time.sleep(0.01) # Small delay per row
        
        sys.stdout.write(f"\rVerzenden... {int((y+1)/360*100)}%")
        sys.stdout.flush()

    # Schakel terug naar Terminal Modus!
    time.sleep(0.5)
    ser.write(b'\x1BTXT')

    print("\n\nKlaar! De afbeelding staat in de SDRAM op de achtergrond!")

except FileNotFoundError:
    print(f"\nFout: Het bestand '{IMAGE_FILE}' is niet gevonden in deze map.")
    print("Zorg dat je een afbeelding met die naam in de map hebt staan.")
except serial.SerialException as e:
    print(f"\nFout bij openen van {COM_PORT}: {e}")
