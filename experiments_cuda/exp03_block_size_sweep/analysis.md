# Result Table from Nsight Compute

## Block Size Sweep

### batch 16 elements 100,000 set

| block size | Achieved Occupancy | SM Throughput | Memory Throughput | Duration | Warp Stall Reasons |
| ---------- | ------------------ | ------------- | ----------------- | -------- | ------------------ |
| 64 | 44.67 | 16.72 | 74.72 | 38.30us | Long Scoreboard 35.99, Not Selected 0.13 |
| 128 | 80.16 | 20.12 | 89.94 | 31.87us | Long Scoreboard 60.76, Not Selected 0.12 |
| 256 | 78.36 | 22.76 | 89.22 | 28.16us | Long Scoreboard 49.63, Not Selected 0.19 |
| 512 | 76.79 | 22.75 | 89.02 | 28.22us | Long Scoreboard 47.03, Not Selected 0.38 |
| 1024| 57.25 | 17.93 | 70.32 | 35.71us | Long Scoreboard 33.34, Not Selected 0.61 |

### batch 16 elements 10,000 set

| block size | Achieved Occupancy | SM Throughput | Memory Throughput | Duration | Warp Stall Reasons |
| ---------- | ------------------ | ------------- | ----------------- | -------- | ------------------ |
| 64 | 58.15 | 10.00 | 45.10 | 6.46 | Long Scoreboard 47.01, Not Selected 0.50 |
| 128 | 75.99 | 11.85 | 53.37 | 5.50 | Long Scoreboard 60.21, Not Selected 0.56 |
| 256 | 78.10 | 11.80 | 53.01 | 5.47 | Long Scoreboard 53.51, Not Selected 0.58 |
| 512 | 80.46 | 11.78 | 53.02 | 5.50 | Long Scoreboard 55.88, Not Selected 0.71 |
| 1024| 55.15 | 10.20 | 45.61 | 6.34 | Long Scoreboard 39.85, Not Selected 0.65 |

- 실험에 사용된 axpby_kernel은 연산이 매우 짧고 빈번하여, 메모리 load/store가 latency에 지배적 (memory-bound)
- 또한 memory-bound인 것은 Long Scoreboard가 높은 것으로 확인할 수 있음 -> Long Scoreboard는 메모리 로드와 같이 지연 시간이 긴 결과를 기다리는 상태를 의미

- block size 64에서는 block 당 warp 수가 낮은 것에 더해, memory-bound인 상황이기 때문에 warp scheduling이 효율적이지 않아 achieved occupancy가 낮게 나온 것으로 보임
  - 그 때문에 latency가 상대적으로 높게 나옴

- block size 128 ~ 512는 block 당 warp수가 어느정도 충분하기 때문에, warp scheduling이 잘 이루어져 achieved occupancy가 75~80 정도 나온 것으로 보임
  - 그 덕분에 latency가 안정적

- block size 1024는 block 당 warp수는 많으나, SM 당 1 block이 할당되어 block간 유동성 및 절대적인 warp 수 부족으로 achieved occupancy가 낮게 나온 것으로 보임
  - 그 때문에 latency가 높게 나옴

- achieved occupancy가 성능과 1대1 대응되지는 않지만, 간단한 연산이기 때문에 warp가 잘 활용되어 latency 성능과 잘 맞아 떨어진 것으로 보임

- 그러므로 이 연산 커널에서의 최적 block size는 중간 사이즈인 128~512이라고 할 수 있음