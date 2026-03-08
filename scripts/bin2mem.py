import sys

def bin2mem(bin_file, mem_file):
    with open(bin_file, 'rb') as f:
        data = f.read()
    
    # Pad to 4-byte boundary
    while len(data) % 4:
        data += b'\x00'
    
    with open(mem_file, 'w') as f:
        for i in range(0, len(data), 4):
            word = int.from_bytes(data[i:i+4], 'little')
            f.write(f'{word:08X}\n')

if __name__ == '__main__':
    bin2mem(sys.argv[1], sys.argv[2])