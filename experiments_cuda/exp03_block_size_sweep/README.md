hypothesis:
1. Increasing thread block size will improve kernel performance by increasing the number of active warps and improving latency hiding.
However, because the kernel is memory-bound, performance is expected to plateau once sufficient occupancy is achieved.

goal:

To evaluate how thread block size affects kernel execution efficiency.

metrics:

- Kernel Runtime
- Achieved occupancy
- Memory throughput
- SM throughput
