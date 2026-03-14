cmake_minimum_required(VERSION 3.24)

project(gpu-execution-sandbox LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CUDA_STANDARD 17)

if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "" FORCE)
endif()

set(CMAKE_CUDA_ARCHITECTURES 89)

add_library(sandbox_common INTERFACE)
target_include_directories(sandbox_common INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})

# exp01
add_executable(exp01_batch_scaling
	experiments_cuda/exp01_batch_scaling/main.cu
)
target_link_libraries(exp01_batch_scaling PRIVATE sandbox_common)

target_compile_options(exp01_batch_scaling PRIVATE
	$<$<COMPILE_LANGUAGE:CUDA>:--use_fast_math>
	$<$<COMPILE_LANGUAGE:CUDA>:-lineinfo>
)

add_executable(exp02_overlap
	experiments_cuda/exp02_overlap/main.cu
)

target_link_libraries(exp02_overlap PRIVATE sandbox_common)

target_compile_options(exp02_overlap PRIVATE
	$<$<COMPILE_LANGUAGE:CUDA>:--use_fast_math>
	$<$<COMPILE_LANGUAGE:CUDA>:-lineinfo>
)

add_executable(exp02_5_overlap_cases
	experiments_cuda/exp02_5_overlap_cases/main.cu
)

target_link_libraries(exp02_5_overlap_cases PRIVATE sandbox_common)

target_compile_options(exp02_5_overlap_cases PRIVATE
	$<$<COMPILE_LANGUAGE:CUDA>:--use_fast_math>
	$<$<COMPILE_LANGUAGE:CUDA>:-lineinfo>
)

add_executable(exp03_block_size_sweep
	experiments_cuda/exp03_block_size_sweep/main.cu
)

target_link_libraries(exp03_block_size_sweep PRIVATE sandbox_common)

target_compile_options(exp03_block_size_sweep PRIVATE
	$<$<COMPILE_LANGUAGE:CUDA>:--use_fast_math>
	$<$<COMPILE_LANGUAGE:CUDA>:-lineinfo>
)
