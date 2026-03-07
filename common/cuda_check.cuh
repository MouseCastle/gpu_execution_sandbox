#pragma once
#include <cstdio>
#include <cstdlib>
#include <cuda_runtime.h>

#define CUDA_CHECK(expr)								\
	do {										\
		cudaError_t _err = (expr); 						\
		if (_err != cudaSuccess) { 						\
			std::fprintf(stderr, "[CUDA] %s failed: %s (%d) at %s:%d\n", 	\
#expr, cudaGetErrorString(_err), (int)_err, __FILE__, __LINE__);			\
			std::exit(1); 							\
		}									\
	} while (0)

