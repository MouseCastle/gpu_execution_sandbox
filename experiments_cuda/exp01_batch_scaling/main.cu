#include <cstdio>
#include <vector>
#include <string>
#include <cstdlib>
#include <numeric>
#include <cuda_runtime.h>

#include "common/cuda_check.cuh"
#include "common/cuda_timer.cuh"
#include "common/bench.hpp"

// elementwise kernel: y = a * x + b
__global__ void axpby_kernel(const float* __restrict__ x,
		float* __restrict__ y,
		int n, float a, float b) {
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	if (i < n) y[i] = a * x[i] + b;
}

struct Args {
	int batch = 1;
	int elements = 512 * 224;
	int iters = 1000;
	int warmup = 100;
	int mode = 0;
	std::string out_csv = "results.csv";
};

static Args parse_args(int argc, char** argv) {
	Args a;
	for (int i = 1; i < argc; ++i) {
		std::string k = argv[i];
		auto next = [&]() -> const char* { return (i + 1 < argc) ? argv[++i] : ""; };

		if (k == "--batch") a.batch = std::atoi(next());
		else if (k == "--elements") a.elements = std::atoi(next());
		else if (k == "--iters") a.iters = std::atoi(next());
		else if (k == "--warmup") a.warmup = std::atoi(next());
		else if (k == "--mode") {
			std::string v = next();
			a.mode = (v == "h2d_kernel_d2h") ? 1 : 0;
		} else if (k == "--out") a.out_csv = next();
	}
	return a;
}

int main(int argc, char** argv) {
	Args args = parse_args(argc, argv);

	const int n = args.batch * args.elements;
	const size_t bytes = size_t(n) * sizeof(float);

	// Host buffers
	std::vector<float> hx(n), hy(n);
	std::iota(hx.begin(), hx.end(), 0.0f);

	// Device buffers
	float *dx = nullptr, *dy = nullptr;
	CUDA_CHECK(cudaMalloc(&dx, bytes));
	CUDA_CHECK(cudaMalloc(&dy, bytes));

	cudaStream_t stream = 0; // start from default stream, can be changed to non-default if needed
	
	// (optional) copy initial data to device if mode requires it
	if (args.mode == 1) {
		CUDA_CHECK(cudaMemcpyAsync(dx, hx.data(), bytes, cudaMemcpyHostToDevice, stream));
		CUDA_CHECK(cudaMemcpyAsync(dy, hy.data(), bytes, cudaMemcpyHostToDevice, stream));
		CUDA_CHECK(cudaStreamSynchronize(stream));
	}

	const int block = 256;
	const int grid = (n + block - 1) / block;

	// Warm-up
	for (int i = 0; i < args.warmup; ++i) {
		if (args.mode == 1) {
			CUDA_CHECK(cudaMemcpyAsync(dx, hx.data(), bytes, cudaMemcpyHostToDevice, stream));
		}
		axpby_kernel<<<grid, block, 0, stream>>>(dx, dy, n, 1.1f, 2.2f);
		CUDA_CHECK(cudaGetLastError());
		if (args.mode == 1) {
			CUDA_CHECK(cudaMemcpyAsync(hy.data(), dy, bytes, cudaMemcpyDeviceToHost, stream));
		}
	}
	CUDA_CHECK(cudaStreamSynchronize(stream));

	// Timed run
	CudaEventTimer gt;
	CpuTimer ct;

	ct.tic();
	gt.tic(stream);

	for (int i = 0; i < args.iters; ++i) {
		if (args.mode == 1) {
			CUDA_CHECK(cudaMemcpyAsync(dx, hx.data(), bytes, cudaMemcpyHostToDevice, stream));
		}
		axpby_kernel<<<grid, block, 0, stream>>>(dx, dy, n, 1.1f, 2.2f);
		CUDA_CHECK(cudaGetLastError());
		if (args.mode == 1) {
			CUDA_CHECK(cudaMemcpyAsync(hy.data(), dy, bytes, cudaMemcpyDeviceToHost, stream));
		}
	}


	float gpu_ms = gt.toc_ms(stream);
	CUDA_CHECK(cudaStreamSynchronize(stream));
	double cpu_ms = ct.toc_ms();

	// validation: check a few elements to prevent over-optimization
	double checksum = 0.0;
	if (args.mode == 1) checksum = hy[0] + hy[n / 2] + hy.back();

	// Throughput: elements per second (kernel-only or end-to-end, same calculation for now)
	const double total_elems = static_cast<double>(n) * static_cast<double>(args.iters);
	const double sec = (cpu_ms / 1000.0);
	const double gelem_per_s = (total_elems / sec) / 1e9;

	std::printf("batch=%d elements=%d n=%d iters=%d mode =%s\n",
			args.batch, args.elements, n, args.iters,
			args.mode ? "h2d_kernel_d2h" : "kernel_only");
	std::printf("gpu_ms(total events)	= %.3f ms\n", gpu_ms);
	std::printf("cpu_ms(total)		= %.3f ms\n", cpu_ms);
	std::printf("throughput			= %.3f Gelem/s\n", gelem_per_s);
	std::printf("checksum			= %.3f\n", checksum);

	// CSV 기록
	const std::string header =
		"batch,elements,iters,warmup,mode,gpu_ms,cpu_ms,throughput_gelem_s,checksum";
	char row[512];
	std::snprintf(row, sizeof(row),
			"%d,%d,%d,%d,%s,%.6f,%.6f,%.6f,%.6f",
			args.batch, args.elements, args.iters, args.warmup,
			args.mode ? "h2d_kernel_d2h" : "kernel_only",
			static_cast<double>(gpu_ms), cpu_ms, gelem_per_s, checksum);

	append_csv_row(args.out_csv, header, row);

	CUDA_CHECK(cudaFree(dx));
	CUDA_CHECK(cudaFree(dy));
	return 0;
}

