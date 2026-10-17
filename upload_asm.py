import sys
import subprocess
import serial
import time
import os

def upload_and_save_asm(asm_file, sd_name, port='COM6', baud=115200):
    bin_file = os.path.splitext(asm_file)[0] + '.bin'
    beebasm = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'beebasm_win', 'beebasm.exe')
    
    print(f"[1/4] Assembleren van {asm_file} met BeebAsm...")
    res = subprocess.run([beebasm, '-i', asm_file, '-o', bin_file], capture_output=True, text=True)
    if res.returncode != 0:
        print("Fout bij assembleren:\n", res.stdout, res.stderr)
        sys.exit(1)
        
    data = open(bin_file, 'rb').read()
    print(f"      Geassembleerd: {bin_file} ({len(data)} bytes pure 6502 machinecode op $6000)")
    
    print(f"[2/4] Verbinden met Tang Nano 20K op {port} ({baud} baud)...")
    s = serial.Serial(port, baud, timeout=1)
    s.write(b'\x1b\r')
    time.sleep(0.2)
    s.read_all()
    
    print(f"[3/4] 6502 Machinecode in RAM ($6000 - ${0x6000+len(data)-1:04X}) plaatsen...")
    # Stuur in blokjes van 8 bytes met 32-bit (!&6000) / byte (?&6000) writes
    chunk_size = 8
    for offset in range(0, len(data), chunk_size):
        chunk = data[offset:offset+chunk_size]
        stmts = [f"?&{0x6000 + offset + i:04X}=&{b:02X}" for i, b in enumerate(chunk)]
        cmd = ":".join(stmts) + "\r"
        s.write(cmd.encode('ascii'))
        time.sleep(0.03)
        s.read_all()
        
    print(f"[4/4] Opslaan op MicroSD-kaart met *BSAVE {sd_name} en starten met *RUN {sd_name}...")
    s.write(f"*BSAVE {sd_name}\r".encode('ascii'))
    time.sleep(1.5)
    out = s.read_all().decode('ascii', 'ignore')
    print(out.strip())
    
    s.write(f"*RUN {sd_name}\r".encode('ascii'))
    time.sleep(2.5)
    out2 = s.read_all()
    clean_out = ''.join(chr(b) if (32 <= b < 127 or b in (10, 13)) else '' for b in out2)
    print(clean_out.strip())
    s.close()

if __name__ == '__main__':
    asm = sys.argv[1] if len(sys.argv) > 1 else 'matrix6502.asm'
    name = sys.argv[2] if len(sys.argv) > 2 else 'MATRIX'
    upload_and_save_asm(asm, name)
