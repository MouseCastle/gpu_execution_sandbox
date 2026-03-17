#include <cuda_runtime.h>

#include <cstdio>
#include <cstdlib>
#include <numeric>
#include <string>
#include <vector>

#include "common/bench.hpp"
#include "common/cuda_check.cuh"
#include "common/cuda_timer.cuh"

enum class AccessPattern : int {
    Coalesced = 0,
    Misaligned = 1,
    Strided = 2,
};

struct Args {
    int elements = 1 << 22;
    int iters = 1000;
    int warmup = 100;
    int block_size = 256;
    int stride = 2;
    int offset = 1;
    std::string pattern = "coalesced";
    std::string out_csv = "results.csv";
};

static Args parse_args(int argc, char** argv)
{
    Args args;
    for (int i = 1; i < argc; ++i) {
        std::string key = argv[i];
        auto next = [&]() -> const char* { return (i + 1 < argc) ? argv[++i] : ""; };

        if (key == "--elements") args.elements = std::atoi(next());
        else if (key == "--iters") args.iters = std::atoi(next());
        else if (key == "--warmup") args.warmup = std::atoi(next());
        else if (key == "--block") args.block_size = std::atoi(next());
        else if (key == "--stride") args.stride = std::atoi(next());
        else if (key == "--offset") args.offset = std::atoi(next());
        else if (key == "--pattern") args.pattern = next();
        else if (key == "--out") args.out_csv = next();
    }
    return args;
}

static bool is_supported_block_size(int block_size)
{
    return block_size > 0 && block_size <= 1024;
}

static AccessPattern parse_pattern(const std::string& pattern)
{
    if (pattern == "coalesced") return AccessPattern::Coalesced;
    if (pattern == "misaligned") return AccessPattern::Misaligned;
    if (pattern == "strided") return AccessPattern::Strided;

    std::fprintf(stderr, "Unsupported pattern: %s\n", pattern.c_str());
    std::fprintf(stderr, "Use one of: coalesced, misaligned, strided\n");
    std::exit(1);
}

static const char* pattern_name(AccessPattern pattern)
{
    switch (pattern) {
    case AccessPattern::Coalesced: return "coalesced";
    case AccessPattern::Misaligned: return "misaligned";
    case AccessPattern::Strided: return "strided";
    default: return "unknown";
    }
}

static size_t max_index_touched(int logical_n, AccessPattern pattern, int stride, int offset)
{
    if (logical_n <= 0) return 0;

    switch (pattern) {
    case AccessPattern::Coalesced:
        return static_cast<size_t>(logical_n - 1);
    case AccessPattern::Misaligned:
        return static_cast<size_t>(logical_n - 1 + offset);
    case AccessPattern::Strided:
        return static_cast<size_t>(logical_n - 1) * static_cast<size_t>(stride);
    default:
        return static_cast<size_t>(logical_n - 1);
    }
}

__host__ __device__ __forceinline__ int compute_index(int tid,
                                                      AccessPattern pattern,
                                                      int stride,
                                                      int offset)
{
    switch (pattern) {
    case AccessPattern::Coalesced:
        return tid;
    case AccessPattern::Misaligned:
        return tid + offset;
    case AccessPattern::Strided:
        return tid * stride;
    default:
        return tid;
    }
}

__global__ void memory_access_kernel(const float* __restrict__ x,
                                     float* __restrict__ y,
                                     int logical_n,
                                     AccessPattern pattern,
                                     int stride,
                                     int offset)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid < logical_n) {
        int idx = compute_index(tid, pattern, stride, offset);
        float v = x[idx];
        y[idx] = 1.1f * v + 2.2f;
    }
}

int main(int argc, char** argv)
{
    Args args = parse_args(argc, argv);
    AccessPattern pattern = parse_pattern(args.pattern);

    if (args.elements <= 0) {
        std::fprintf(stderr, "elements must be > 0\n");
        return 1;
    }
    if (args.iters <= 0 || args.warmup < 0) {
        std::fprintf(stderr, "iters must be > 0 and warmup must be >= 0\n");
        return 1;
    }
    if (!is_supported_block_size(args.block_size)) {
        std::fprintf(stderr, "block must be in range 1..1024\n");
        return 1;
    }
    if (args.stride <= 0) {
        std::fprintf(stderr, "stride must be > 0\n");
        return 1;
    }
    if (args.offset < 0) {
        std::fprintf(stderr, "offset must be >= 0\n");
        return 1;
    }

    const size_t physical_n = max_index_touched(args.elements, pattern, args.stride, args.offset) + 1;
    const size_t bytes = physical_n * sizeof(float);

    std::vector<float> hx(physical_n);
    std::vector<float> hy(physical_n, 0.0f);
    std::iota(hx.begin(), hx.end(), 0.0f);

    float* dx = nullptr;
    float* dy = nullptr;
    CUDA_CHECK(cudaMalloc(&dx, bytes));
    CUDA_CHECK(cudaMalloc(&dy, bytes));

    CUDA_CHECK(cudaMemcpy(dx, hx.data(), bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemset(dy, 0, bytes));

    const int block = args.block_size;
    const int grid = (args.elements + block - 1) / block;

    for (int i = 0; i < args.warmup; ++i) {
        memory_access_kernel<<<grid, block>>>(
            dx, dy, args.elements, pattern, args.stride, args.offset);
        CUDA_CHECK(cudaGetLastError());
    }
    CUDA_CHECK(cudaDeviceSynchronize());

    CudaEventTimer gt;
    CpuTimer ct;

    ct.tic();
    gt.tic();

    for (int i = 0; i < args.iters; ++i) {
        memory_access_kernel<<<grid, block>>>(
            dx, dy, args.elements, pattern, args.stride, args.offset);
        CUDA_CHECK(cudaGetLastError());
    }

    float gpu_ms = gt.toc_ms();
    CUDA_CHECK(cudaDeviceSynchronize());
    double cpu_ms = ct.toc_ms();

    CUDA_CHECK(cudaMemcpy(hy.data(), dy, bytes, cudaMemcpyDeviceToHost));

    const size_t first_index = static_cast<size_t>(compute_index(0, pattern, args.stride, args.offset));
    const size_t last_index = max_index_touched(args.elements, pattern, args.stride, args.offset);
    const int mid_tid = args.elements / 2;
    const size_t mid_index = static_cast<size_t>(compute_index(mid_tid, pattern, args.stride, args.offset));
    const double checksum = hy[first_index] + hy[mid_index] + hy[last_index];

    const double useful_bytes = double(args.elements) * double(sizeof(float)) * 2.0 * double(args.iters);
    const double sec = cpu_ms / 1000.0;
    const double requested_gb_per_s = (useful_bytes / sec) / 1e9;
    const double avg_iter_ms = cpu_ms / double(args.iters);
    const double span_ratio = double(physical_n) / double(args.elements);

    int device = 0;
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDevice(&device));
    CUDA_CHECK(cudaGetDeviceProperties(&prop, device));

    int max_active_blocks = 0;
    CUDA_CHECK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(
        &max_active_blocks, memory_access_kernel, block, 0));
    const double estimated_occupancy =
        (double(max_active_blocks * block) / double(prop.maxThreadsPerMultiProcessor)) * 100.0;

    std::printf("pattern=%s elements=%d physical_n=%zu block=%d grid=%d\n",
                pattern_name(pattern), args.elements, physical_n, block, grid);
    std::printf("stride=%d offset=%d span_ratio=%.2f\n", args.stride, args.offset, span_ratio);
    std::printf("gpu_ms(total compute timeline) = %.3f ms\n", gpu_ms);
    std::printf("cpu_ms(total)                  = %.3f ms\n", cpu_ms);
    std::printf("avg_iter_ms                    = %.6f ms\n", avg_iter_ms);
    std::printf("requested_bandwidth            = %.3f GB/s\n", requested_gb_per_s);
    std::printf("estimated_occupancy            = %.2f %%\n", estimated_occupancy);
    std::printf("checksum                       = %.6f\n", checksum);

    const std::string header =
        "pattern,elements,iters,warmup,block_size,stride,offset,physical_n,span_ratio,gpu_ms,cpu_ms,avg_iter_ms,requested_bandwidth_gb_s,estimated_occupancy,checksum";

    char row[1024];
    std::snprintf(row, sizeof(row),
                  "%s,%d,%d,%d,%d,%d,%d,%zu,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f",
                  pattern_name(pattern), args.elements, args.iters, args.warmup, block,
                  args.stride, args.offset, physical_n, span_ratio, double(gpu_ms), cpu_ms,
                  avg_iter_ms, requested_gb_per_s, estimated_occupancy, checksum);

    append_csv_row(args.out_csv, header, row);

    CUDA_CHECK(cudaFree(dx));
    CUDA_CHECK(cudaFree(dy));
    return 0;
}
