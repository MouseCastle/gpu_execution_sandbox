# NSIGHT COMPUTE CHECKLIST

## 1️⃣ DRAM Throughput

### Metric

> dram__throughput.pct_of_peak_sustained_elapsed

### Meaning

> memory bandwidth usage

| value | meaning |
| ----- | ------- |
| <50%  | able to compute |
| 70%+  | memory pressure |
| 90%+  | memory bound |

## 2️⃣ SM Throughput

### Metric

> sm__throughput

### meaning

> ALU utilization

## 3️⃣ Achieved Occupancy

### Metric

> sm__warps_active.avg.pct_of_peak_sustained_active

### Meaning

> latency hiding capacity

## 4️⃣ Warp Execution Efficiency

### Metric

> warp_execution_efficiency

### Meaning

> warp divergence

## 5️⃣ Global Memory Load Efficiency

### Metric

> gld_efficiency

### Meaning

> coalescing quality

## 6️⃣ Global Memory Store Efficiency

### Metric

> gst_efficiency


## 7️⃣ L2 Cache Hit Rate

### Metric

> lts__t_sectors_hit_rate

## 8️⃣ L1 Cache Hit Rate

### Metric

> l1tex__t_sectors_pipe_lsu_mem_global_op_ld_lookup_hit_rate

## 9️⃣ DRAM Bytes

### Metric

> dram__bytes

- kernel memory traffic

## 1️⃣0️⃣ Shared Memory Throughput

## Metric

> shared_load_transactions

## 1️⃣1️⃣ Stall Long Scoreboard

### Metric

> smsp__warp_issue_stalled_long_scoreboard

### Meaning

> memory latency stall

## 1️⃣2️⃣ Stall Memory Dependency

### Metric

> smsp__warp_issue_stalled_membar

## 1️⃣3️⃣ Stall Not Selected

### Metric

> smsp_warp_issue_stalled_not_selected

- scheduler pressure

## 1️⃣4️⃣ IPC (Instructions per Cycle)

### Metric

> smsp__inst_executed_per_cycle

## 1️⃣5️⃣ Eligible Warps Per Cycle

### Metric

> smsp__warps_elegible

- scheduler health

## Order of viewing metrics

1️⃣

> dram throughput

- check memory bound

2️⃣

> SM throughput

- check compute bound

3️⃣

> occupancy

- latency hiding

4️⃣

> memory efficiiency

- check coalescing

5️⃣

> stall reason

- root cause analysis