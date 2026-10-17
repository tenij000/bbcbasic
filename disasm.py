import sys

def disassemble(filename):
    # Lees HEX file en maak 8KB binary
    mem = [0] * 8192
    with open(filename, 'r') as f:
        for line in f:
            if line.startswith('@'):
                # Not standard Intel Hex, maybe it's just raw hex?
                pass
            else:
                words = line.strip().split()
                if len(words) > 0:
                    try:
                        # Assuming it's already flat hex from convert_hex.py
                        pass
                    except:
                        pass
                        
    # It's a flat hex file from convert_hex.py! Each line has hex values.
    addr = 0
    with open(filename, 'r') as f:
        for line in f:
            words = line.strip().split()
            for w in words:
                mem[addr] = int(w, 16)
                addr += 1
                
    reset_vector = mem[0x1FFC] | (mem[0x1FFD] << 8)
    print(f"Reset vector: {hex(reset_vector)}")
    
    # Very simple disassembler for the start
    pc = 0xFD05 - 0xE000
    for _ in range(20):
        if pc < 0 or pc >= 8192:
            break
        op = mem[pc]
        print(f"{hex(pc + 0xE000)}: {hex(op)} {hex(mem[pc+1])} {hex(mem[pc+2])}")
        
        if op in [0x20, 0x4C, 0xAD, 0x8D, 0xC9]: pc += 3
        elif op in [0xA9, 0xC0, 0xD0, 0xF0, 0xA2, 0xA0, 0x10, 0x30, 0x90, 0xB0, 0x29]: pc += 2
        else: pc += 1

disassemble('src/ehbasic.hex')
