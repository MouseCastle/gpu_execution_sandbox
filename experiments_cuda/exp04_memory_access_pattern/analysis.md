# Result Table

| pattern | elements | iters | warmup | block_size | stride | offset | physical_n | span_ratio | gpu_ms | cpu_ms | avg_iter_ms | requested_bandwidth_gb_s | estimated_occupancy | checksum |
| ------- | -------- | ----- | ------ | ---------- | ------ | ------ | ---------- | ---------- | ------ | ------ | -------- | ------------------ | --------------------- | -------- |
| coalesced | 4194304 | 1000 | 100 | 256 | 3 | 3 | 4194304 | 1.000000 | 44.473343 | 44.528300 | 0.044528 | 753.552954 | 100.000000 | 6920607.000000 |
| misaligned | 4194304 | 1000 | 100 | 256 | 3 | 3 | 4194307 | 1.000001 | 60.056511 | 60.088600 | 0.060089 | 558.415939 | 100.000000 | 6920617.000000 |
| strided | 4194304 | 1000 | 100 | 256 | 3 | 3 | 12582910 | 3.000000 | 874.930176 | 874.978200 | 0.874978 | 38.348878 | 100.000000 | 20761808.000000 | 

- 표에서 requested_bandwidth_gb_s는 4070 laptop 기준 실제 최대 DRAM throughput인 256GB/s를 훨ㄴㄴ씬 상회하는 결과를 보이는데, 이는 실제 DRAM throughput이 아닌 코드 내 계산에 의한 결과로, 절대 지표로서 읽기보다 throughput 비교를 위한 상대 지표 정도로 해석하는 게 바람직할 것
(throughput이 너무 높은 이유는 L2 메모리에 데이터가 상주하여, L2에 의한 throughput 상승으로 볼 수 있으며, 실제 L2에 상주하지 않도록 데이터를 번갈아 로드할 시, 약 227GB/s로 memory throughput 상한에 걸리는 것을 확인하였음)

- 하나의 warp는 32개의 thread를 갖고 있으며, 메모리 로드 시 기본적으로 128bytes씩 불러올 수 있음
- 또한 메모리 주소 상 128byte 단위로 요청을 하기 때문에, 초기에 할당된 데이터가 128bytes aligned되어 있을 때, 조금씩 어긋날 경우 더 많은 메모리를 요청하게 됨
- 그 때문에 처리하는 메모리가 128byte로 aligned되어 있을 때, 메모리 로드 시 coalesced되어 최대 효율을 낼 수 있음
- 추가적으로 128byte외에 sub section으로 64byte, 32byte를 불러올 수 있어 misaligned된 상황에 따라 32또는 64 byte 단위로 추가 로드 가능 (효율은 128byte에 비해 떨어짐)

## Case A: Coalesced

- coalesced는 elements가 2^22이며, 데이터 로드 시 128byte씩 coalesced loading을 최대 효율로 쓸 수 있음
- 가까운 cache memory의 이점을 얻기 좋은 구조
- 결과를 보면, 가장 낮은 gpu latency를 보이며, throughput 또한 가장 높은 걸 알 수 있음

## Case B: Misaligned

- misaligned의 경우, offset에 의해 메모리 align이 살짝 어긋난 상태로 메모리를 로드하는데, 이 때문에 128byte 경계에 걸쳐 데이터롤 로드하게 됨
- offset이 3일 경우, 3개의 float이 어긋난 채로 있으므로 warp가 추가 메모리르 요청할 수 있음
- latency가 coalesced에 비해 조금 상승한 것을 볼 수 있는데, 아직은 cache memory의 이점을 얻기 좋은 구조이기 때문에 더 큰 latency 증가를 보이지는 않음

## Case C: Strided

- strided는 최악의 성능을 보여주고 있는데, 이는 메모리 로드 효율도 최악이며 cache 효율도 떨어져 latency가 상당히 증가한 것을 볼 수 있음
- cache hit율도 상당히 떨어지지만, 데이터를 한 번에 요청하기 어려워 각 thread가 받기 위한 메모리를 DRAM에게서 최악의 효율로 불러오게 되어 이러한 결과가 된 것으로 보임

## Conclusion

- 메모리 align 및 cache 효율에 의해 coalesced가 가장 좋은 성능을 보임 (latency, throughput)
- memory bound 연산에서는 coalesced를 구성하는 것만으로도 상당한 성능 개선이 될 수 있어, 매우 효율적인 최적화를 수행할 수 있을 것