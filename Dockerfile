# 1. ベースイメージをUbuntu 24.04ベースのCUDA 13.1（最新）に変更
# ※公式イメージのタグを確認し、開発用(devel)を指定します
FROM nvidia/cuda:13.1.0-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive

# 2. Ubuntu 24.04でgcc-11をインストール
# Ubuntu 24.04のデフォルトはgcc-13ですが、ホストOSの構成に合わせてgcc-11を指定
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc-11 \
    g++-11 \
    cmake \
    git \
    wget \
    ca-certificates \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# 3. コンパイラの優先順位設定
# Ubuntu 24.04ではデフォルトがgcc-13なので、明示的に11を使うようパスを通します
ENV CC=/usr/bin/gcc-11
ENV CXX=/usr/bin/g++-11

# 4. CUDA環境の設定
ENV CUDA_PATH=/usr/local/cuda
ENV PATH=${CUDA_PATH}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_PATH}/lib64:${LD_LIBRARY_PATH}

WORKDIR /opt

# 5. CpHMDソースコードの取得
RUN git clone https://gitlab.mpcdf.mpg.de/grubmueller/fmm.git && \
    cd fmm && \
    git checkout constant_ph_stable

# 6. ビルドプロセス
WORKDIR /opt/fmm
RUN mkdir -p build && cd build && \
    cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DGMX_BUILD_OWN_FFTW=ON \
    -DGMX_GPU=CUDA \
    -DGMX_SIMD=AUTO \
    -DGMX_WITH_FMM=ON \
    -DGMX_CONSTANTPH=ON \
    -DGMX_MPI=OFF \
    -DCMAKE_C_COMPILER=/usr/bin/gcc-11 \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++-11 \
    -DCMAKE_CUDA_COMPILER=${CUDA_PATH}/bin/nvcc \
    -DCUDA_NVCC_FLAGS="-Xcompiler;-fPIC" \
    -DGMX_CUDA_TARGET_SM=80 \
    .. && \
    make -j$(nproc) gmx

# 7. 実行環境の設定
ENV PATH=/opt/fmm/build/bin:$PATH
RUN echo "source /opt/fmm/build/bin/GMXRC" >> /etc/bash.bashrc

WORKDIR /simulation
CMD ["/bin/bash"]
