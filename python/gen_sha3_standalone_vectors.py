import hashlib

IN    = "E:/539Labs/test_vectors/stimulus_pipeline.dat"
S_OUT = "E:/539Labs/test_vectors/stimulus_sha3.dat"
E_OUT = "E:/539Labs/test_vectors/expected_sha3.dat"

with open(IN) as f:
    lines = [l.strip() for l in f if l.strip()][:10]

with open(S_OUT, 'w') as sf, open(E_OUT, 'w') as ef:
    for line in lines:
        # stimulus_pipeline.dat format is "index,128hex"; extract the hex portion
        seed_hex = line.split(',')[-1].strip()
        seed_bytes = bytes.fromhex(seed_hex)
        digest = hashlib.sha3_512(seed_bytes).hexdigest()
        sf.write(seed_hex + '\n')
        ef.write(digest + '\n')

print("Generated 10 SHA3-512 standalone test vectors")
print(f"  stimulus_sha3.dat: first entry = {lines[0][:16]}...")
print(f"  Files: {S_OUT}")
print(f"         {E_OUT}")