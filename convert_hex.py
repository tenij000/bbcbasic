import sys

rom = [0xEA] * 16384

try:
    with open('src/BASIC.HEX', 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line[0] != ':': continue
            byte_count = int(line[1:3], 16)
            address = int(line[3:7], 16)
            record_type = int(line[7:9], 16)
            
            if record_type == 0: 
                for i in range(byte_count):
                    data_byte = int(line[9+i*2 : 11+i*2], 16)
                    rom[address + i] = data_byte
                    
    with open('src/ehbasic.hex', 'w') as out:
        for i in range(8192):
            out.write(f'{rom[i]:02X}\n')
            
    print('Intel HEX succesvol omgezet naar ehbasic.hex (8KB)!')
    reset_vector = rom[0x1FFC] | (rom[0x1FFD] << 8)
    print(f'Reset vector in ROM is: {hex(reset_vector)}')
    
    # Read UART address from ROM if possible
    # Usually around reset vector or character out routines
except Exception as e:
    print('Fout:', e)
