import glob
import os

XSIM_DIR = r'E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim'

PATTERNS = ['xsim_run_*.f', 'sim_demo_*.log']

total = 0
for pattern in PATTERNS:
    files = sorted(glob.glob(os.path.join(XSIM_DIR, pattern)))
    for f in files:
        os.remove(f)
        print(f"  Deleted: {os.path.basename(f)}")
        total += 1

print(f"\nDone. {total} artifact file(s) removed.")