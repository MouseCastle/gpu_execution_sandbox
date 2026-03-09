- exp02에서는 copy/compute stream을 분리 하였고, kernel이 앞선 H2D 이벤트를 기다리게 함으로써 H2D 후 kernel의 논리적 순서는 지키도록 하고, 후에 kernel과 D2H는 겹쳐짐으로써 작은 overlap이 발생하도록 함
- 여전히 kernel의 연산은 크기 않기 때문에 kernel 연산 전에는 항상 H2D의 event를 기다리는 시간이 길고, 다 기다린 후 kernel은 즉시 끝나며 kernel 시작과 거의 비슷한 시기에 D2H가 겹쳐져 실행됨 (event/stream 적으로 엮인 것이 없음)

[`nsight systems overlap`](./screenshots/exp02_overlap_nsight_systems.png)

- 의도대로 겹쳐짐을 확인