#include <cuda_runtime.h>
#include <vector>
#include <iostream>

__global__ void axpby_kernel(float* x, float* y, int n, float a, float b)
{
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	if (i < n)
		y[i] = a * x[i] + b;
}

int main() 
{
	const int elements = 512 * 224 * 64;
	const int batch = 16;
	const int N = elements * batch;
	const size_t bytes = N * sizeof(float);

	float *hx;
	float *hy;

	// pinned memory
	cudaHostAlloc(&hx, bytes, cudaHostAllocDefault);
	cudaHostAlloc(&hy, bytes, cudaHostAllocDefault);

	for (int i = 0; i < N; ++i)
		hx[i] = static_cast<float>(i);

	float *dx[2];
	float *dy[2];

	cudaMalloc(&dx[0], bytes);
	cudaMalloc(&dx[1], bytes);
	cudaMalloc(&dy[0], bytes);
	cudaMalloc(&dy[1], bytes);

	cudaStream_t stream_copy;
	cudaStream_t stream_compute;

	cudaStreamCreate(&stream_copy);
	cudaStreamCreate(&stream_compute);

	cudaEvent_t copy_done[2];
	cudaEventCreate(&copy_done[0]);
	cudaEventCreate(&copy_done[1]);

	int block = 256;
	int grid = (N + block - 1) / block;

	for (int i = 0; i < 10; ++i)
	{
		int b = i % 2;

		// HtoD copy
		cudaMemcpyAsync(dx[b], hx, bytes, cudaMemcpyHostToDevice, stream_copy);

		cudaEventRecord(copy_done[b], stream_copy);

		cudaStreamWaitEvent(stream_compute, copy_done[b], 0);

		// kernel
		axpby_kernel<<<grid, block, 0, stream_compute>>>(dx[b], dy[b], N, 1.1f, 2.2f);

		// DtoH
		cudaMemcpyAsync(hy, dy[b], bytes, cudaMemcpyDeviceToHost, stream_copy);
	}

	cudaDeviceSynchronize();

	std::cout << "done\n";
}
