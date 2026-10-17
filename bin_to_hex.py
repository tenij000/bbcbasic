with open('BBCBasicSBC02/build/SBC02.bin', 'rb') as f:
    data = f.read()
with open('bbcbasic.hex', 'w') as f:
    for b in data:
        f.write(f'{b:02X}\n')
