#!/bin/bash
set -ex

test -f $PREFIX/include/cutensor.h
test -f $PREFIX/include/cutensorMg.h
test -f $PREFIX/include/cutensor/types.h
test -f $PREFIX/lib/libcutensor.so
test -f $PREFIX/lib/libcutensorMg.so

# the aarch64 binary requires newer glibc that conda-forge currently lacks
if [[ $target_platform == linux-aarch64 ]]; then
    exit 0
fi
# we cross-build for ppc64le and it does not have newer glibc either
if [[ $target_platform == linux-ppc64le ]]; then
    exit 0
fi

${GCC} test_load_elf.c -std=c99 -Werror -ldl -o test_load_elf
# need to load the stub for CUDA 12
if [[ "${cuda_compiler_version}" =~ 12.* ]]; then
    export CUDA_STUB="$PREFIX/lib/stubs/libcuda.so"
fi    
LD_PRELOAD="$CUDA_STUB" ./test_load_elf $PREFIX/lib/libcutensor.so
LD_PRELOAD="$CUDA_STUB" ./test_load_elf $PREFIX/lib/libcutensorMg.so

NVCC_FLAGS=""
# Workaround __ieee128 error; see https://github.com/LLNL/blt/issues/341
if [[ $target_platform == linux-ppc64le && $cuda_compiler_version == 10.* ]]; then
    NVCC_FLAGS+=" -Xcompiler -mno-float128"
fi

compile () {
    local source=${1}
    local output=${2}
    local link_libraries=${3}
    local command="nvcc --verbose ${NVCC_FLAGS} --std=c++11 -I${PREFIX}/include -L${PREFIX}/lib ${link_libraries} ${source} -o ${output}"
    
    # nvcc --verbose ${NVCC_FLAGS} --std=c++11 -I${PREFIX}/include -L${PREFIX}/lib ${link_libraries} ${source} -o ${output}
    # local _output=$( eval "${command}" 2>&1 ; )
    # local _status=$?
    
    # if [ ${_status} -ne 0 ]; then
    #   EXIT_STATUS=${_status}
    #   echo "detected nonzero exit code: ${_exit}"
    #   echo "error compiling ${source}"
    #   echo "${_output}"
    # else
    #   echo "detected zero exit code: ${_exit}"
    #   echo "successfully compiled ${source}"
    # fi
}

# EXIT_STATUS=0
git clone https://github.com/NVIDIA/CUDALibrarySamples.git sample_linux/
cd sample_linux/cuTENSOR/
compile "contraction.cu" "contraction" "-lcutensor -lcudart"
# error_log=$(nvcc $NVCC_FLAGS --std=c++11 -I$PREFIX/include -L$PREFIX/lib -lcutensor -lcudart contraction.cu -o contraction 2>&1)
# echo $error_log
compile "reduction.cu" "reduction" "-lcutensor -lcudart"
# error_log=$(nvcc $NVCC_FLAGS --std=c++11 -I$PREFIX/include -L$PREFIX/lib -lcutensor -lcudart reduction.cu -o reduction 2>&1)
# echo $error_log
cd ../cuTENSORMg/
compile "contraction_multi_gpu.cu" "contraction_multi_gpu" "-lcutensorMg -lcutensor -lcudart"
# error_log=$(nvcc $NVCC_FLAGS --std=c++11 -I$PREFIX/include -L$PREFIX/lib -lcutensorMg -lcutensor -lcudart contraction_multi_gpu.cu -o contraction_multi_gpu 2>&1)
# echo $error_log

# exit ${EXIT_STATUS}
