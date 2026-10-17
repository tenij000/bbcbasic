import serial
import time
import argparse

def main():
    parser = argparse.ArgumentParser(description='Send color to Tang Nano 20K MiniGPU.')
    parser.add_argument('--port', '-p', type=str, required=True, help='COM port (e.g., COM3)')
    parser.add_argument('--color', '-c', type=str, default='FF0000', help='Hex color code (e.g., FF0000 for red, 00FF00 for green)')
    
    args = parser.parse_args()
    
    port = args.port
    color = args.color
    
    # Parse color string
    try:
        if color.startswith('#'):
            color = color[1:]
        if len(color) != 6:
            raise ValueError
        r = int(color[0:2], 16)
        g = int(color[2:4], 16)
        b = int(color[4:6], 16)
    except ValueError:
        print("Invalid color format. Please use hex format like 'FF0000'.")
        return

    print(f"Connecting to {port} at 115200 baud...")
    
    try:
        ser = serial.Serial(port, 115200, timeout=1)
        time.sleep(1) # Wait for serial connection to settle
        
        print(f"Sending color: R={r} G={g} B={b}")
        ser.write(bytes([r, g, b]))
        
        print("Color sent!")
        ser.close()
        
    except serial.SerialException as e:
        print(f"Error opening serial port {port}: {e}")
        print("Please make sure the COM port is correct and not used by another program.")

if __name__ == '__main__':
    main()
