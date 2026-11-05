import hashlib, time, os

N   = 100_000
msg = os.urandom(64)   # 64-byte random message, matches FPGA benchmark input size

start   = time.perf_counter()
for _   in range(N):
    hashlib.sha3_512(msg).digest()
elapsed = time.perf_counter() - start

us_per_hash   = elapsed / N * 1e6
hashes_per_sec = N / elapsed

result = (
    f"SHA3-512 CPU Benchmark\n"
    f"Platform: Python hashlib\n"
    f"Input size: 64 bytes\n"
    f"Iterations: {N:,}\n\n"
    f"Total time:    {elapsed:.3f} s\n"
    f"Throughput:    {hashes_per_sec:,.0f} hashes/sec  ({hashes_per_sec/1e6:.3f} MH/s)\n"
    f"Latency:       {us_per_hash:.4f} us/hash\n"
)
print(result)

out_path = "E:/539Labs/benchmarks/M7_cpu_benchmark.txt"
with open(out_path, 'w') as f:
    f.write(result)
print(f"Saved to {out_path}")