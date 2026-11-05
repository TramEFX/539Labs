import hashlib, random, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from hqh539 import T3, STEPS, SALT_STD, DOMAIN_SEP

random.seed(539)
tv_dir = os.path.join(os.path.dirname(__file__), '..', 'test_vectors')
os.makedirs(tv_dir, exist_ok=True)

with open(os.path.join(tv_dir, 'stimulus_phase3.dat'), 'w') as sf, \
     open(os.path.join(tv_dir, 'expected_phase3.dat'), 'w') as ef:
    for i in range(20):
        seed_val = random.getrandbits(512)
        state = seed_val
        for _ in range(STEPS):
            state = T3(state)
        state_bytes = state.to_bytes(32, 'big')
        digest = hashlib.sha3_512(state_bytes + SALT_STD + DOMAIN_SEP).digest()
        sf.write(f"{i},{state_bytes.hex()}\n")
        ef.write(f"{i},{digest.hex()}\n")
        
print("20 phase3 vectors written.")