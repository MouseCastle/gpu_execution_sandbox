#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>
#include <numeric>

#include "common/cuda_check.cuh"
#include "common/cuda_timer.cuh"
#include "common/bench.hpp"

__global__ void axpby_kernel(const float* __restrict__ x,
                             float* __restrict__ y,
                             int n,
                             float a,
                             float b)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        y[i] = a * x[i] + b;
    }
}

struct Args {
    int batch = 16;
    int elements = 512 * 224;
    int iters = 1000;
    int warmup = 100;
    int block_size = 256;
    std::string out_csv = "results.csv";
};

static Args parse_args(int argc, char** argv)
{
    Args args;
    for (int i = 1; i < argc; ++i) {
        std::string key = argv[i];
        auto next = [&]() -> const char* { return (i + 1 < argc) ? argv[++i] : ""; };

        if (key == "--batch") args.batch = std::atoi(next());
        else if (key == "--elements") args.elements = std::atoi(next());
        else if (key == "--iters") args.iters = std::atoi(next());
        else if (key == "--warmup") args.warmup = std::atoi(next());
        else if (key == "--block") args.block_size = std::atoi(next());
        else if (key == "--out") args.out_csv = next();
    }
    return args;
}

static bool is_supported_block_size(int block_size)
{
    switch (block_size) {
    case 64:
    case 128:
    case 256:
    case 512:
    case 1024:
        return true;
    default:
        return false;
    }
}

int main(int argc, char** argv)
{
    Args args = parse_args(argc, argv);

    if (!is_supported_block_size(args.block_size)) {
        std::fprintf(stderr, "Unsupported block size: %d\n", args.block_size);
        std::fprintf(stderr, "Use one of: 64, 128, 256, 512, 1024\n");
        return 1;
    }

    const int n = args.batch * args.elements;
    const size_t bytes = size_t(n) * sizeof(float);

    std::vector<float> hx(n), hy(n, 0.0f);
    std::iota(hx.begin(), hx.end(), 0.0f);

    float* dx = nullptr;
    float* dy = nullptr;
    CUDA_CHECK(cudaMalloc(&dx, bytes));
    CUDA_CHECK(cudaMalloc(&dy, bytes));

    CUDA_CHECK(cudaMemcpy(dx, hx.data(), bytes, cudaMemcpyHostToDevice));

    const int block = args.block_size;
    const int grid = (n + block - 1) / block;

    for (int i = 0; i < args.warmup; ++i) {
        axpby_kernel<<<grid, block>>>(dx, dy, n, 1.1f, 2.2f);
        CUDA_CHECK(cudaGetLastError());
    }
    CUDA_CHECK(cudaDeviceSynchronize());

    CudaEventTimer gt;
    CpuTimer ct;

    ct.tic();
    gt.tic();

    for (int i = 0; i < args.iters; ++i) {
        axpby_kernel<<<grid, block>>>(dx, dy, n, 1.1f, 2.2f);
        CUDA_CHECK(cudaGetLastError());
    }

    float gpu_ms = gt.toc_ms();
    CUDA_CHECK(cudaDeviceSynchronize());
    double cpu_ms = ct.toc_ms();

    CUDA_CHECK(cudaMemcpy(hy.data(), dy, bytes, cudaMemcpyDeviceToHost));

    double checksum = hy[0] + hy[n / 2] + hy[n - 1];
    const double total_elems = double(n) * double(args.iters);
    const double sec = cpu_ms / 1000.0;
    const double gelem_per_s = (total_elems / sec) / 1e9;
    const double avg_iter_ms = cpu_ms / double(args.iters);

    int device = 0;
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDevice(&device));
    CUDA_CHECK(cudaGetDeviceProperties(&prop, device));

    int max_active_blocks = 0;
    CUDA_CHECK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(
        &max_active_blocks, axpby_kernel, block, 0));
    const int max_threads_per_sm = prop.maxThreadsPerMultiProcessor;
    const double estimated_occupancy =
        (double(max_active_blocks * block) / double(max_threads_per_sm)) * 100.0;

    std::printf("block=%d grid=%d n=%d\n", block, grid, n);
    std::printf("gpu_ms(total compute timeline) = %.3f ms\n", gpu_ms);
    std::printf("cpu_ms(total)                  = %.3f ms\n", cpu_ms);
    std::printf("avg_iter_ms                    = %.6f ms\n", avg_iter_ms);
    std::printf("throughput                     = %.3f Gelem/s\n", gelem_per_s);
    std::printf("estimated_occupancy            = %.2f %%\n", estimated_occupancy);
    std::printf("checksum                       = %.6f\n", checksum);

    const std::string header =
        "block_size,batch,elements,iters,warmup,grid_size,gpu_ms,cpu_ms,avg_iter_ms,throughput_gelem_s,estimated_occupancy,checksum";

    char row[1024];
    std::snprintf(row, sizeof(row),
                  "%d,%d,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f",
                  block, args.batch, args.elements, args.iters, args.warmup, grid,
                  (double)gpu_ms, cpu_ms, avg_iter_ms, gelem_per_s, estimated_occupancy, checksum);

    append_csv_row(args.out_csv, header, row);

    CUDA_CHECK(cudaFree(dx));
    CUDA_CHECK(cudaFree(dy));
    return 0;
}