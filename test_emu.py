import sys
import time
from py65.devices.mpu6502 import MPU

def load_bin(filename, memory, address):
    with open(filename, 'rb') as f:
        data = f.read()
        memory[address:address+len(data)] = data

def main():
    memory = bytearray(65536)
    load_bin('BBCBasicSBC02/build/SBC02.hex', memory, 0xC000)
    mpu = MPU()
    mpu.memory = memory
    
    def pop():
        mpu.sp = (mpu.sp + 1) & 0xFF
        return memory[0x100 + mpu.sp]
    
    # Read reset vector
    mpu.pc = memory[0xFFFC] | (memory[0xFFFD] << 8)
    print(f"Reset vector: {hex(mpu.pc)}")
    
    # We will simulate typing in BASIC
    input_buffer = list(b'GCOL 0, 1\rGLINE 10, 20, 100, 200\r')
    
    step_count = 0
    max_steps = 10000000
    
    while step_count < max_steps:
        pc = mpu.pc
        
        # OSRDCH intercept
        if pc == 0xFFE0: # OSRDCH vector
            if input_buffer:
                char = input_buffer.pop(0)
                mpu.a = char
                mpu.p &= ~0x01 # clear carry
                # return
                addr = pop()
                addr |= (pop() << 8)
                mpu.pc = addr + 1
                continue
            else:
                break
                
        # OSWRCH intercept
        if pc == 0xFFEE: # OSWRCH vector
            char = mpu.a
            print(f"VDU: {char} (0x{char:02x})")
            addr = pop()
            addr |= (pop() << 8)
            mpu.pc = addr + 1
            continue

        try:
            mpu.step()
        except Exception as e:
            print(f"Exception at PC={hex(pc)}: {e}")
            break
        step_count += 1
        
    print(f"\nEmulation ended after {step_count} steps.")

if __name__ == '__main__':
    main()
