### GPU_EXECUTION_FUNDAMENTALS

## Memory-bound

- 커널 연산에서의 memory-bound의 개념은 커널 내 연산이 아닌 메모리 load/store가 지배적임을 뜻함
- 예제 초반부의 axpby_kernel의 경우, 연산은 1~2회뿐이기 때문에 메모리 load/store가 빈번하게 일어남
- 그 때문에 커널이 메모리 load/store를 기다리게 되고, 이 시간이 latency를 지배하기 때문에 이는 memory-bound라고 하는 것
  - 물론 l1/l2 등의 cache를 이용하게 된다면 memory-bound가 해소될 수 있지만,
  지금의 커널은 연산이 얕기 때문에 memory-bound임은 변함이 없을 것

## VRAM bandwidth

- VRAM에서 SM으로 데이터를 초당 얼마나 보낼 수 있는가에 대한 capability
- GDDR6/GDDR5X 그래픽 메모리는 14Gbps (Gigabit/sec)의 속도로 데이터를 전송
- `RTX 4070 laptop` 기준 메모리 인터페이스는 128bit
- VRAM bandwidth는 14Gbps * 128 / 8 = 224 GB/s로 계산됨 (8은 bit to byte 연산)
- `Memory throughput(%)`은 총 bandwidth 대비 몇 퍼센트의 데이터 전송 속도를 사용 중인가에 대한 지표

## SM warps

- Ada 계열인 compute capability 8.9 기준으로 SM 한도는,
  - warp size: 32
  - resident warps per SM 최대: 48
  - resident threads per SM 최대: 1536 (48 warps * 32 threads)
  - resident blocks per SM 최대: 24 (1536 threads / 64 threads per block)
- block size 64
  - SM 당 갖게되는 block 수: 1536 / 64 = 24 (blocks per SM)
  - block 당 할당되는 warp 수: 64 / 32 = 2 (warps per block)
  - SM이 활용 가능한 warp 수: 24 * 2 = 48 (warps per SM)
- block size 256
  - SM 당 갖게되는 block 수: 1536 / 256 = 6
  - block 당 할당되는 warp 수: 256 / 32 = 8
  - SM이 활용 가능한 warp 수: 6 * 8 = 48
- block size 1024
  - SM 당 갖게되는 block 수: 1536 / 1024 = 1
  - block 당 할당되는 warp 수: 1024 / 32 = 32
  - SM이 활용 가능한 warp 수: 1 * 32 = 32
- block size가 너무 적음    -> resident warp가 적어 유동적 스케쥴링이 어려움
- block size가 너무 큼      -> resident block이 적어 block 간 유동성 및 할당 warp 수 감소에 의해 연산 효율 감소

> SM과 block
> SM은 block을 0~n개 할당 가능
> block은 SM을 1개씩 할당
> **block 당 최대 threads는 제한되어 있음. (invalid kernel launch)** (일반적으로 최대 block size는 1024)

## Achieved Occupancy

- Active warps = Issued Warps(연산 중인 워프) + Stalled Warps(데이터 기다리는 워프) + Ready Warps(다음 차례 기다리는 워프)
- Achieved Occupancy는 평균 Active warps / HW Max warps
  - 이 비율의 연산은 커널이 끝날 때까지 모든 cycle 마다 active warps를 누계하여, cycle * HW Max warps로 나눈 비율
- Achieved Occupancy가 높다는 것은, 활용할 수 있는 Ready Warps가 많아 latency hiding이 잘 일어날 수 있다는 것
  - Warp가 Stalled일 때, 스케쥴러는 이를 기다려주지 않음.
  - 다음 대기 중인 Warp를 골라 Issue를 발행 -> 이 과정에서 stall이 hiding이 되고 결과적으로는 latency hiding이 일어남

> Scheduler in SM
> Ada 기준 SM 당 4개의 Scheduler가 있음 (동시에 4개의 warp에 명령 내리기 가능)
> SM 당 warp가 최대 48개일 때, Scheduler 하나 당 12개의 warp가 배정되며, 이 안에서만 명령을 내릴 수 있음
> 한 Scheduler가 갖고 있는 warps가 모두 issued일 때, 다른 Scheduler의 warps가 Ready 상태더라도 가져다 쓸 수 없음
> - 대체로 각 Scheduler가 담당하는 warp 집합이 고정되어 있어 **cross-scheduler borrowing을 기대하지 않는 편이 좋음**
