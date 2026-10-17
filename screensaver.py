import serial
import serial.tools.list_ports
import time
import sys
import os
import glob
try:
    from PIL import Image
except ImportError:
    print("De 'Pillow' library is niet gevonden. Installeer deze via:")
    print("pip install pillow")
    sys.exit(1)

# Configuratie
IMAGES_DIR = 'images'
DELAY_SECONDS = 15  # Aantal seconden per afbeelding op het scherm

# Zoek alle afbeeldingen in de map
supported_extensions = ['*.jpg', '*.jpeg', '*.png', '*.bmp']
image_files = []
for ext in supported_extensions:
    image_files.extend(glob.glob(os.path.join(IMAGES_DIR, ext)))

if not image_files:
    print(f"Geen afbeeldingen gevonden in map '{IMAGES_DIR}'. Zet er wat in!")
    # Als de boerderij in de hoofdmap staat, kunnen we die ook gebruiken
    if os.path.exists('boerderij.jpg'):
        print("Ik gebruik boerderij.jpg als fallback.")
        image_files.append('boerderij.jpg')
    else:
        sys.exit(1)

print(f"{len(image_files)} afbeelding(en) gevonden voor de screensaver!")

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
        return 0xFE # Voorkom dat wit als sync byte wordt gezien in andere projecten
    return color

try:
    ser = serial.Serial(COM_PORT, 115200, timeout=1)
    print(f"Verbonden met {COM_PORT}.")
    
    # We sturen een paar lege bytes om de lijn wakker te schudden en dan het 
    # magische commando om over te schakelen naar de FPGA image modus.
    ser.write(b'\0\0\0\0\0\0') 
    time.sleep(0.5)
    ser.write(b'\x1BIMG') 
    time.sleep(0.1)

    index = 0
    while True:
        current_image = image_files[index]
        print(f"\n[{index+1}/{len(image_files)}] Afbeelding '{current_image}' inladen...")
        
        img = Image.open(current_image)
        # Verklein naar 640x360 voor de SDRAM resolutie!
        img = img.resize((640, 360), Image.Resampling.LANCZOS)
        img = img.convert('RGB')
        
        pixels = img.load()
        pixel_data = bytearray()
        
        for y in range(360):
            for x in range(640):
                r, g, b = pixels[x, y]
                color_8bit = rgb_to_8bit(r, g, b)
                pixel_data.append(color_8bit)
                
        # Send row by row to prevent CH340 buffer overflow on Windows
        row_size = 640
        for y in range(360):
            row_data = pixel_data[y*row_size : (y+1)*row_size]
            ser.write(row_data)
            time.sleep(0.01) # Kleine vertraging per regel
            
            sys.stdout.write(f"\rUploaden... {int((y+1)/360*100)}%")
            sys.stdout.flush()

        print(f"\nAfbeelding staat op het scherm! Wacht {DELAY_SECONDS} seconden...")
        time.sleep(DELAY_SECONDS)
        
        # Volgende afbeelding in de lijst pakken (en begin opnieuw als we aan het eind zijn)
        index = (index + 1) % len(image_files)

except serial.SerialException as e:
    print(f"\nFout bij openen of gebruiken van poort {COM_PORT}: {e}")
except KeyboardInterrupt:
    print("\n\nScreensaver gestopt door gebruiker. (Ctrl+C ingedrukt)")
    sys.exit(0)
