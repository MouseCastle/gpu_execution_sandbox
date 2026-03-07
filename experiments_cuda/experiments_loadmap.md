# EXPERIMENTS_LOADMAP

## Exp01 - Batch Scaling

### Purpose

> confirm GPU parallelism saturation

### Observation Point

- increase throughput → plateau → decrease
- DRAM bandwidth saturation
- latency hiding

### Nsight Compute

> dram__throughput
> sm__throughput
> stall_long_scoreboard

## Exp02 - Overlap Baseline

### Structure

> H2D
> kernel
> D2H

### Problem

> serialize execution

### Purpose

> baseline without overlap

## Exp02.5 - Overlap Verification

### Structure

> H2D
> kernel
> H2D(next batch)

### Purpose

> copy + compute overlap

### Confirmation

- in Nsight Systems,

> compute
> copy 

- overlap

## Exp03 - Block Size Sweep

### Purpose

> understanding the Occupancy vs. Performance relationship

### Experiment

> blockDim.x
>
> 64
> 128
> 256
> 512
> 1024

### Measurement

> achieved occupancy
> SM throughput

### Key Question

> Is a larger block size always better?

## Exp04 - Memory Access Pattern

### Purpose

> understanding the impact of coalescing

### 3 Kernels

> coalesced
> strided
> random

### Example

> a[idx]
> a[idx*stride]
> a[random[idx]]

### Measurement

> Global Memory Load Efficiency
> DRAM throughput

## Exp05 - Shared Memory Optimization

### Purpose

> shared memory reuse

### Experiment

> global only
> vs.
> shared memory tiliing

### Example

> matrix tile
> stencil

### Measurement

> DRAM throughput
> L1/L2 hit rate

## Exp06 - Register Pressure

### Purpose

> register vs. occupancy tradeoff

### Method

> artifivially increasing register usage

### Example

> float r0,r1,r2,...,r32

### Measurement

> achieved occupancy
> SM throughput

## Exp07 Kernel Fusion

### Purpose

> decreasing global memory traffic

### Comparison

> kernel1 + kernel2
> vs
> fused kernel

### Measurement

> dram bytes
> execution time

## Exp08 - Double Buffer Pipeline

### Structure

> stream1 → compute batch0
> stream2 → copy batch1

### Purpose

> copy latency hiding

### Confirmation

- Nsight Systems timeline overlap

## Exp09 - Triple Buffer Pipeline

### Structure

> copy
> compute
> copy

### 3-Stage Pipeline

> H2D
> kernel
> D2H

- Launching simultaneously

## Exp10 - Ring Buffer GPU Pipeline

### Example

> capture
> GPU preprocess
> GPU compute
> display

### Buffer

> buffer0
> buffer1
> buffer2

## Exp11 - Persistent Kernel

- GPU Worker Model

### Structure

> launch kernel
> loop forever

- GPU processes task queue

### Usage

> stream processing
> ray tracing
> simulation

## Exp12 - Full GPU Pipeline

- Final experiment

### Structure

> CPU capture
> ↓
> GPU preprocess
> ↓
> GPU compute
> ↓
> GPU postprocess
> ↓
> display

### Purpose

> GPU idle = 0