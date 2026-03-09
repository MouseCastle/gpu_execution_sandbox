[NVidia GPU RTX 4070 Laptop]

- throughput peak는 batch 32에서 보임
- 24/32/64 ncu 결과,

| DRAM | SM Compute | Occupancy |
| ---- | ---------- | --------- |
| 90%+ | 20% | 80% |

- DRAM은 이미 포화 상태
- Compute는 많이 남는 상태
- 메모리 때문에 Compute가 기다리는 구조

`Memory Bound Kernel`

- arithmetic intensity가 변하지 않기 때문에, compute의 비중은 변하지 않음
- 오히려 이미 포화 상태이기 때문에 memory load를 기다리는 시간이 길어지고, 절대적인 연산량이 많아지기 때문에 batch 증가 == latency 증가로 이어짐

- Max Bandwidth는 거의 90%+ 이상의 결과를 보이는 데, 이는 커널이 load/store 한 번에 적은 연산을 보이기 때문에, 연산이 빨리 끝나버려 load를 또 요청하는 상태이기 때문에 Max Bandwidth가 증가할 수 밖에 없는 커널 구조

`low arithmetic intensity`