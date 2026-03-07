# CUDA PIPELINE ARCHITECTURES

## 1️⃣ Batch Execution Pattern

> load batch
> → kernel
> → output

### example

> deep learning inference
> matrix compute

### feature

> simple
> high compute density

### problem

> large latency

## 2️⃣ Double Buffer Pipeline

- Basic pattern for the GPU pipeline

> buffer A → compute
> buffer B → copy

- proceed simultaneously

> time →
> copy A
> compute A
>
> copy B
> compute B

### effect

> copy latency hiding

## 3️⃣ Stream Overlap Pipeline

- using CUDA stream

> stream1 → copy
> stream2 → compute

### structure

> H2D
> kernel
> D2H

- launch this on multi-streams

## 4️⃣ Ring Buffer GPU Pipeline

- Widely used in real-time systems

### example

> camera
> video
> sensor

### structure

> capture
> ↓
> process
> ↓
> render

## 5️⃣ Stage Pipeline Pattern

- Multiple GPU Stages

### exmaple

> decode
> preprocess
> inference
> postprocess
> render

- Each stage runs simultaneously

## 6️⃣ Kernel Fusion Pattern

- Very important in optimizing GPU performance

### example

> normalize
> resize
> transform
> ↓
> single kernel

## 7️⃣ Persistent Kernel Pattern

- A pattern often used by CUDA experts

### example

> launch once
> loop forever

### structure

> GPU worker thread

### usage example

> stream processing
> video processing
> ray tracing

## 8️⃣ Multi-GPU Pipeline

- used in large systems

### example

> GPU0 → preprocess
> GPU1 → inference
> GPU2 → render

or 

> data parallel
