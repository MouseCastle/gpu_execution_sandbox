#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>
#include <numeric>
#include <iostream>
#include <functional>

#include "common/cuda_check.cuh"
#include "common/cuda_timer.cuh"
#include "common/bench.hpp"

__global__ void axpby_kernel(const float* __restrict__ x,
                             float* __restrict__ y,
                             int n, float a, float b)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) y[i] = a * x[i] + b;
}

enum class CaseType {
    A_pageable_single_single = 0,
    B_pinned_single_single   = 1,
    C_pinned_two_single      = 2,
    D_pinned_two_double      = 3,
    E_pinned_copy_overlap    = 4
};

struct Args {
    int batch = 16;
    int elements = 512 * 224;
    int iters = 1000;
    int warmup = 100;
    std::string out_csv = "results.csv";
    CaseType case_type = CaseType::A_pageable_single_single;
};

static Args parse_args(int argc, char** argv)
{
    Args a;
    for (int i = 1; i < argc; ++i) {
        std::string k = argv[i];
        auto next = [&]() -> const char* { return (i + 1 < argc) ? argv[++i] : ""; };

        if (k == "--batch") a.batch = std::atoi(next());
        else if (k == "--elements") a.elements = std::atoi(next());
        else if (k == "--iters") a.iters = std::atoi(next());
        else if (k == "--warmup") a.warmup = std::atoi(next());
        else if (k == "--out") a.out_csv = next();
        else if (k == "--case") {
            std::string v = next();
            if (v == "A") a.case_type = CaseType::A_pageable_single_single;
            else if (v == "B") a.case_type = CaseType::B_pinned_single_single;
            else if (v == "C") a.case_type = CaseType::C_pinned_two_single;
            else if (v == "D") a.case_type = CaseType::D_pinned_two_double;
            else if (v == "E") a.case_type = CaseType::E_pinned_copy_overlap;
        }
    }
    return a;
}

static const char* case_name(CaseType c)
{
    switch (c) {
    case CaseType::A_pageable_single_single: return "A_pageable_single_single";
    case CaseType::B_pinned_single_single:   return "B_pinned_single_single";
    case CaseType::C_pinned_two_single:      return "C_pinned_two_single";
    case CaseType::D_pinned_two_double:      return "D_pinned_two_double";
    case CaseType::E_pinned_copy_overlap:    return "E_pinned_copy_overlap";
    default: return "unknown";
    }
}

struct CaseOptions {
    bool pinned = false;
    int num_streams = 1;
    int num_buffers = 1;
};

int main(int argc, char** argv)
{
    Args args = parse_args(argc, argv);

    const int n = args.batch * args.elements;
    const size_t bytes = size_t(n) * sizeof(float);

    CaseOptions case_{};

    switch (args.case_type) {
        case CaseType::A_pageable_single_single:
            case_ = {false, 1, 1};
            break;
        case CaseType::B_pinned_single_single:
            case_ = {true, 1, 1};
            break;
        case CaseType::C_pinned_two_single:
            case_ = {true, 2, 1};
            break;
        case CaseType::D_pinned_two_double:
            case_ = {true, 2, 2};
            break;
        case CaseType::E_pinned_copy_overlap:
            case_ = {true, 2, 2};
            break;
        default:
            std::fprintf(stderr, "Invalid case type\n");
            return 1;
    }

    // Host buffers
    float* hx[2] = { nullptr, nullptr };
    float* hy[2] = { nullptr, nullptr };

    for (int i = 0; i < case_.num_buffers; ++i) {
        if (case_.pinned) {
            CUDA_CHECK(cudaHostAlloc(&hx[i], bytes, cudaHostAllocDefault));
            CUDA_CHECK(cudaHostAlloc(&hy[i], bytes, cudaHostAllocDefault));
        } else {
            hx[i] = (float*)std::malloc(bytes);
            hy[i] = (float*)std::malloc(bytes);
            if (!hx[i] || !hy[i]) {
                std::fprintf(stderr, "Host allocation failed\n");
                return 1;
            }
        }

        for (int j = 0; j < n; ++j) {
            hx[i][j] = float(j + i * 0.01f);
            hy[i][j] = 0.0f;
        }
    }

    // Device buffers
    float* dx[2] = { nullptr, nullptr };
    float* dy[2] = { nullptr, nullptr };
    for (int i = 0; i < case_.num_buffers; ++i) {
        CUDA_CHECK(cudaMalloc(&dx[i], bytes));
        CUDA_CHECK(cudaMalloc(&dy[i], bytes));
    }

    // Streams
    cudaStream_t stream[2] = {0, 0};

    if (case_.num_streams == 2) {
        CUDA_CHECK(cudaStreamCreate(&stream[0]));
        CUDA_CHECK(cudaStreamCreate(&stream[1]));
    } else {
        stream[0] = 0;
        stream[1] = 0;
    }

    // Events
    cudaEvent_t copy_done[2] = { nullptr, nullptr };
    cudaEvent_t kernel_done[2] = { nullptr, nullptr };

    for (int i = 0; i < case_.num_buffers; ++i) {
        CUDA_CHECK(cudaEventCreate(&copy_done[i]));
        CUDA_CHECK(cudaEventCreate(&kernel_done[i]));
    }

    const int block = 256;
    const int grid = (n + block - 1) / block;

    const bool is_double_buffer = case_.num_buffers == 2;

    std::function<void(int)> one_iteration = nullptr;
    
    if (args.case_type == CaseType::E_pinned_copy_overlap) {
        /*
            In this case, we want to overlap the HtoD copy of the next buffer
            with the kernel execution of the current buffer.
        */
        one_iteration = [&](int iter) {
            if (case_.num_buffers != 2) {
                std::fprintf(stderr, "Case E requires 2 buffers\n");
                std::exit(1);
            }

            // HtoD
            for (int i = 0; i < case_.num_buffers; ++i) {
                CUDA_CHECK(cudaMemcpyAsync(dx[i], hx[i], bytes, cudaMemcpyHostToDevice, stream[i]));
                CUDA_CHECK(cudaEventRecord(copy_done[i], stream[i]));
            }
            for (int i = 0; i < case_.num_buffers; ++i) {            
                CUDA_CHECK(cudaStreamWaitEvent(stream[i], copy_done[i], 0));
            }

            // Kernel dependency on HtoD
            for (int i = 0; i < case_.num_buffers; ++i) {
                axpby_kernel<<<grid, block, 0,  stream[i]>>>(dx[i], dy[i], n, 1.1f, 2.2f);
                CUDA_CHECK(cudaGetLastError());
            }
            
            // DtoH
            for (int i = 0; i < case_.num_buffers; ++i) {
                CUDA_CHECK(cudaMemcpyAsync(hy[i], dy[i], bytes, cudaMemcpyDeviceToHost, stream[i]));
            }
        };
    } else {
        one_iteration = [&](int iter) {
            const int b = iter % case_.num_buffers;

            cudaStream_t& stream_copy = is_double_buffer ? stream[b] : stream[0];
            cudaStream_t& stream_compute = is_double_buffer ? stream[b] : stream[1];

            // HtoD
            CUDA_CHECK(cudaMemcpyAsync(dx[b], hx[b], bytes, cudaMemcpyHostToDevice, stream_copy));
            CUDA_CHECK(cudaEventRecord(copy_done[b], stream_copy));

            // Kernel dependency on HtoD
            if (args.case_type == CaseType::C_pinned_two_single) {
                CUDA_CHECK(cudaStreamWaitEvent(stream_compute, copy_done[b], 0));
            }

            axpby_kernel<<<grid, block, 0, stream_compute>>>(dx[b], dy[b], n, 1.1f, 2.2f);
            CUDA_CHECK(cudaGetLastError());

            CUDA_CHECK(cudaMemcpyAsync(hy[b], dy[b], bytes, cudaMemcpyDeviceToHost, stream_copy));
        };
    }

    // Warmup
    for (int i = 0; i < args.warmup; ++i) {
        one_iteration(i);
    }
    CUDA_CHECK(cudaDeviceSynchronize());

    // Timed run
    CudaEventTimer gt;
    CpuTimer ct;

    cudaStream_t last_stream = is_double_buffer ? stream[args.iters % 2 + 1] : stream[1];

    int iters = args.iters;
    if (args.case_type == CaseType::E_pinned_copy_overlap) {
        // For the overlap case, we need to run one extra iteration to fully utilize the pipeline
        last_stream = stream[1]; // The last kernel will be on stream[1]
        iters /= case_.num_buffers;
    }

    ct.tic();
    gt.tic(last_stream);

    for (int i = 0; i < iters; ++i) {
        one_iteration(i);
    }

    float gpu_ms = gt.toc_ms(last_stream);
    CUDA_CHECK(cudaDeviceSynchronize());
    double cpu_ms = ct.toc_ms();

    // checksum
    double checksum = 0.0;
    for (int i = 0; i < case_.num_buffers; ++i) {
        checksum += hy[i][0];
        checksum += hy[i][n / 2];
        checksum += hy[i][n - 1];
    }

    const double total_elems = double(n) * double(iters);
    const double sec = cpu_ms / 1000.0;
    const double gelem_per_s = (total_elems / sec) / 1e9;
    const double avg_iter_ms = cpu_ms / double(iters);

    std::printf("case=%s\n", case_name(args.case_type));
    std::printf("batch=%d elements=%d n=%d buffers=%d pinned=%d num_streams=%d\n",
                args.batch, args.elements, n, case_.num_buffers, (int)case_.pinned, case_.num_streams);
    std::printf("gpu_ms(total compute timeline) = %.3f ms\n", gpu_ms);
    std::printf("cpu_ms(total)                  = %.3f ms\n", cpu_ms);
    std::printf("avg_iter_ms                    = %.6f ms\n", avg_iter_ms);
    std::printf("throughput                     = %.3f Gelem/s\n", gelem_per_s);
    std::printf("checksum                       = %.6f\n", checksum);

    const std::string header =
        "case,batch,elements,iters,warmup,buffers,pinned,two_streams,gpu_ms,cpu_ms,avg_iter_ms,throughput_gelem_s,checksum";

    char row[1024];
    std::snprintf(row, sizeof(row),
                  "%s,%d,%d,%d,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f",
                  case_name(args.case_type),
                  args.batch, args.elements, iters, args.warmup,
                  case_.num_buffers, (int)case_.pinned, case_.num_streams,
                  (double)gpu_ms, cpu_ms, avg_iter_ms, gelem_per_s, checksum);

    append_csv_row(args.out_csv, header, row);

    // cleanup
    for (int i = 0; i < case_.num_buffers; ++i) {
        CUDA_CHECK(cudaFree(dx[i]));
        CUDA_CHECK(cudaFree(dy[i]));
        CUDA_CHECK(cudaEventDestroy(copy_done[i]));
        CUDA_CHECK(cudaEventDestroy(kernel_done[i]));

        if (case_.pinned) {
            CUDA_CHECK(cudaFreeHost(hx[i]));
            CUDA_CHECK(cudaFreeHost(hy[i]));
        } else {
            std::free(hx[i]);
            std::free(hy[i]);
        }
    }

    if (case_.num_streams == 2) {
        CUDA_CHECK(cudaStreamDestroy(stream[0]));
        CUDA_CHECK(cudaStreamDestroy(stream[1]));
    }

    return 0;
}
