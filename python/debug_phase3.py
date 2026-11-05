import hashlib

RC = [
    0x0000000000000001,0x0000000000008082,0x800000000000808A,0x8000000080008000,
    0x000000000000808B,0x0000000080000001,0x8000000080008081,0x8000000000008009,
    0x000000000000008A,0x0000000000000088,0x0000000080008009,0x000000008000000A,
    0x000000008000808B,0x800000000000008B,0x8000000000008089,0x8000000000008003,
    0x8000000000008002,0x8000000000000080,0x000000000000800A,0x800000008000000A,
    0x8000000080008081,0x8000000000008080,0x0000000080000001,0x8000000080008008
]
RHO = [[0,36,3,41,18],[1,44,10,45,2],[62,6,43,15,61],[28,55,25,21,56],[27,20,39,8,14]]

def rot(v,n): return ((v<<n)|(v>>(64-n)))&0xFFFFFFFFFFFFFFFF

def keccak_f1600(K):
    A = [[K[5*y+x] for y in range(5)] for x in range(5)]
    for r in range(24):
        C = [A[x][0]^A[x][1]^A[x][2]^A[x][3]^A[x][4] for x in range(5)]
        D = [C[(x+4)%5]^rot(C[(x+1)%5],1) for x in range(5)]
        A = [[A[x][y]^D[x] for y in range(5)] for x in range(5)]
        B = [[0]*5 for _ in range(5)]
        for x in range(5):
            for y in range(5):
                B[y][(2*x+3*y)%5] = rot(A[x][y], RHO[x][y])
        A = [[(B[x][y]^((~B[(x+1)%5][y])&B[(x+2)%5][y]))&0xFFFFFFFFFFFFFFFF
              for y in range(5)] for x in range(5)]
        A[0][0] ^= RC[r]
    out = [0]*25
    for x in range(5):
        for y in range(5):
            out[5*y+x] = A[x][y]
    return out

msg = bytes.fromhex("000000000000000a4a7ced1542a10592b1572f177b27ca8c2a29533730917099") \
      + b"539-LABS-2026-RESONANT-SALT" + b":HQH-539-RESONANT:"

K = [0]*25
for i in range(9):
    K[i] ^= int.from_bytes(msg[8*i:8*i+8], 'little')
print(f"K[0] before perm1 : {K[0]:016x}")

K = keccak_f1600(K)
print(f"K[0] after  perm1 : {K[0]:016x}")

block1 = list(msg[72:77]) + [0x06] + [0x00]*65 + [0x80]
for i in range(9):
    K[i] ^= int.from_bytes(bytes(block1[8*i:8*i+8]), 'little')
print(f"K[0] before perm2 : {K[0]:016x}")

K = keccak_f1600(K)
print(f"K[0] after  perm2 : {K[0]:016x}")

digest = b"".join(K[i].to_bytes(8,'little') for i in range(8))
print(f"Python result     : {digest.hex()}")
print(f"hashlib verify    : {hashlib.sha3_512(msg).hexdigest()}")