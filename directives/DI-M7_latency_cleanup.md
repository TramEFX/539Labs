# DI-M7 — Latency Characterization and Artifact Cleanup

**Project:** HQH-539 Demo Engine ↔ XSim Hardware Integration
**Milestone:** DI-M7
**Status:** PENDING
**Issued by:** Orchestrator (Claude)
**Assigned to:** Builder (Grok)
**Date:** June 10, 2026

---

## Prerequisites

DI-M1 through DI-M6 are COMPLETE. The Flask demo is running end-to-end with XSim.
Do not re-derive anything. All path constants and conventions are fixed below.

**Key paths:**
```
XSIM_DIR = E:\539Labs\vivado\hqh539_t3core.sim\sim_1\behav\xsim\
DEMO_DIR  = E:\539Labs\demo\
```

---

## Overview

Three tasks. Complete them in order. After each task, report verbatim output back to
Orchestrator before proceeding to the next. Do not proceed to Task B until Orchestrator
confirms Task A output. Do not proceed to Task C — that is Orchestrator-only.

---

## Task A — Artifact Cleanup Script

Write the following script exactly as specified. Do NOT run it yet. Report the script
content back to Orchestrator for review, then await instruction to run.

**File:** `E:\539Labs\demo\cleanup_xsim_artifacts.py`
**Encoding:** UTF-8, no BOM

```python
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
```

**Run from:** any directory (script uses absolute path).
**Expected output:** one line per deleted file, then summary count.
**Safe to run:** bridge recreates these files on every invocation. No permanent data loss.

Report the exact console output back to Orchestrator.

---

## Task B — Per-Invocation Benchmark Script

Write the following script exactly as specified. Do NOT run it until Orchestrator
confirms Task A is complete and gives the go-ahead.

**File:** `E:\539Labs\demo\benchmark_xsim.py`
**Encoding:** UTF-8, no BOM

```python
import sys
import os
import statistics

sys.path.insert(0, r'E:\539Labs\demo')
from xsim_bridge import hqh539_via_xsim_timed

# Fixed test seed — SHA3-512 of b"539-benchmark" as hex (128 chars).
# Any valid 128-char hex is acceptable for latency measurement.
SEED_HEX = (
    '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b'
    '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b'
)
N = 10

print(f"HQH-539 XSim per-invocation benchmark — N={N}")
print(f"Seed: {SEED_HEX[:16]}...{SEED_HEX[-8:]}")
print("-" * 60)

wall_ms_list = []

for i in range(N):
    result = hqh539_via_xsim_timed(SEED_HEX)
    wall_ms = result['wall_ms']
    wall_ms_list.append(wall_ms)
    print(f"  Run {i+1:2d}/{N}:  {wall_ms:7.1f} ms   digest={result['digest'][:16]}...")

print("-" * 60)

mn  = min(wall_ms_list)
mx  = max(wall_ms_list)
avg = statistics.mean(wall_ms_list)
sd  = statistics.stdev(wall_ms_list)

print(f"Results (ms):")
print(f"  min:    {mn:.1f}")
print(f"  max:    {mx:.1f}")
print(f"  mean:   {avg:.1f}")
print(f"  stddev: {sd:.1f}")
print()
print(f"Mean in seconds: {avg/1000:.3f} s")
print(f"Full encrypt estimate (2 x mean): {2*avg/1000:.3f} s")
print(f"Full decrypt estimate (2 x mean): {2*avg/1000:.3f} s")
print()
print("Category B — single machine (TRAM-GPC1), N=10 independent calls.")
```

**Run from:** any directory.
**Expected behavior:** 10 sequential XSim invocations (~40–45 s total). Each run
prints immediately on completion. No parallelism — bridge holds a threading.Lock.

Report the exact console output (all 10 run lines + summary block) back to Orchestrator.

---

## Task C — Decision Gate (ORCHESTRATOR ONLY)

Do not implement anything for Task C. After Orchestrator reviews the Task B output,
Orchestrator will issue one of the following continuations:

**If mean ≤ 5.0 s:**
Per-call architecture is acceptable. Orchestrator marks DI-M7 COMPLETE and issues
DI-M8 directive (Orchestrator writes verify_xsim_integration.py — not Grok).

**If mean > 5.0 s:**
Orchestrator evaluates persistent XSim subprocess architecture:
- Bridge holds a long-running xsim process
- Communicates via stdin/stdout pipe
- Eliminates ~3 s startup per call; target ~1.3 s/call (amortized from DI-M1)
- Significant complexity increase — only pursue if latency is a real problem
Orchestrator will issue a separate directive if this path is chosen.

---

## Encoding and File-Write Reminder

For all `.py` files: UTF-8, no BOM.
Use:
```powershell
[System.IO.File]::WriteAllText("path\to\file", $content,
  (New-Object System.Text.UTF8Encoding $false))
```
Do NOT use `Out-File -Encoding utf8` (adds BOM).

---

## Reporting Protocol

1. Write Task A script → paste full script content to Orchestrator → await go-ahead to run.
2. Run Task A → paste exact console output to Orchestrator → await go-ahead for Task B.
3. Write Task B script → paste full script content to Orchestrator → await go-ahead to run.
4. Run Task B → paste exact console output to Orchestrator → stop. Task C is Orchestrator-only.

Do not skip steps or combine them.

---

*Directive issued by: Orchestrator (Claude)*
*539 Labs LLC | HQH-539 Demo Engine ↔ XSim Integration*
