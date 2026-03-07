#pragma once
#include <cuda_runtime.h>
#include "common/cuda_check.cuh"

struct CudaEventTimer {
	cudaEvent_t start{};
	cudaEvent_t stop{};

	CudaEventTimer() {
		CUDA_CHECK(cudaEventCreate(&start));
		CUDA_CHECK(cudaEventCreate(&stop));
	}
	~CudaEventTimer() {
		cudaEventDestroy(start);
		cudaEventDestroy(stop);
	}

	void tic(cudaStream_t stream = 0) { CUDA_CHECK(cudaEventRecord(start, stream)); }
	float toc_ms(cudaStream_t stream = 0) {
		CUDA_CHECK(cudaEventRecord(stop, stream));
		CUDA_CHECK(cudaEventSynchronize(stop));
		float ms = 0.0f;
		CUDA_CHECK(cudaEventElapsedTime(&ms, start, stop));
		return ms;
	}
};
