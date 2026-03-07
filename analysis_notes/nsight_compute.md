# NSight Compute

## Key Metrics

### **1️⃣ DRAM Throughput**

- GPU DRAM 대역폭을 sustained peak 대비 몇 % 사용했는가?
- Memory-heavy kernel에서 가장 직접적인 병목 지표

| 값 | 의미 |
|---|---|
| <40% | compute bound 가능성 |
| 40~70% | mixed |
| 70~85% | memory pressure |
| 85~95% | memory bound 가능성 매우 높음 |

### **2️⃣ SM Throughput**

- GPU ALU 연산 자원 사용률
- Compute bound를 볼 수 있음

| DRAM | SM | 해석 |
|------|----|-----|
| 높음 | 낮음 | memory bound |
| 낮음 | 높음 | compute bound |
| 둘 다 높음 | balanced	|  |

### **3️⃣ Achieved Occupancy**

- SM이 동시에 실행하는 warp 비율
- GPU는 많은 warp로 memory latency를 숨김

| occupancy  | 의미    |
| ---------- | ----- |
| <25%       | 매우 낮음 |
| 25~50%     | 부족    |
| **50~70%** | 보통    |
| **70%+**   | 충분    |

### **4️⃣ Global Memory Load Efficiency

- 요청한 데이터 대비 실제 DRAM transaction 효율
- GPU memory는 보통 32B / 64B / 128B transaction 단위
- 이 지표가 낮으면 확인할 원인
  - stride access
  - unaligned access
  - scatter read

| 효율     | 의미            |
| ------ | ------------- |
| >90%   | 매우 좋음         |
| 70~90% | 괜찮음           |
| <70%   | coalescing 문제 |

### **5️⃣ L2 Cache Hit Rate**

- L2 cache에서 데이터 재사용 비율

| L2 hit | 의미                  |
| ------ | ------------------- |
| >70%   | cache reuse 있음      |
| 40~70% | 일반                  |
| <40%   | 거의 streaming access |

### **6️⃣ Warp Stall Reason**

- warp가 왜 기다리는 지
- GPU scheduler가 warp를 실행하려는데 dependency 때문에 stall 되는 이유
- 가장 중요한 stall은 memory kernel에서 `long scoreboard` (global memory load 기다리는 중)

| stall type      | 의미                 |
| --------------- | ------------------ |
| long scoreboard | memory latency     |
| not selected    | scheduler issue    |
| barrier         | sync               |
| math pipe       | compute dependency |
