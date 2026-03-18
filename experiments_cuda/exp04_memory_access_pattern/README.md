This experiment explores **memory access patterns**.

I will compare **coalesced**, **misaligned**, and **strided** access to observe how access pattern changes memory efficiency and kernel performance.

hypothesis:
1. Coalesced access will show the best memory throughput and shortest duration.
2. Misaligned access will introduce some inefficiency, but the penalty may be smaller than strided access.
3. Strided access will reduce memory efficiency the most because a warp will touch a wider memory span.

observation points:
1. Global Memory Load Efficiency
2. Memory Throughput / DRAM Throughput
3. Kernel Duration
4. Warp Stall Reasons
