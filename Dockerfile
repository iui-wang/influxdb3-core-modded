# syntax=docker/dockerfile:1
# 在 Ubuntu 20.04 容器内编译 InfluxDB 3 Core 魔改版，目标 glibc >= 2.31
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

# 国内 apt 镜像（海外构建可注释掉）
RUN sed -i 's|archive.ubuntu.com|mirrors.ustc.edu.cn|g; s|security.ubuntu.com|mirrors.ustc.edu.cn|g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential lld pkg-config protobuf-compiler libprotobuf-dev cmake curl ca-certificates xz-utils git \
       libssl-dev zlib1g-dev libffi-dev libsqlite3-dev libbz2-dev liblzma-dev libreadline-dev libncursesw5-dev uuid-dev tk-dev patchelf \
    && rm -rf /var/lib/apt/lists/*

# Python 3.12 源码编译（focal 源里没有），--enable-shared 供 pyo3 链接
RUN curl -fSL https://www.python.org/ftp/python/3.12.11/Python-3.12.11.tgz -o /tmp/py.tgz \
    && tar -C /tmp -xf /tmp/py.tgz \
    && cd /tmp/Python-3.12.11 \
    && ./configure --enable-shared --prefix=/opt/python312 LDFLAGS="-Wl,-rpath,/opt/python312/lib" \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/py.tgz /tmp/Python-3.12.11

# Rust 1.97.1（国内使用 rsproxy 镜像，海外可换成官方 rustup）
ENV RUSTUP_DIST_SERVER=https://rsproxy.cn \
    RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup \
    PATH=/root/.cargo/bin:$PATH \
    PYO3_PYTHON=/opt/python312/bin/python3.12 \
    CARGO_TARGET_DIR=/build/target
RUN curl -sSf https://rsproxy.cn/rustup-init.sh | sh -s -- -y --default-toolchain 1.97.1 --profile minimal \
    && mkdir -p /root/.cargo \
    && printf '%s\n' \
       '[source.crates-io]' 'replace-with = "rsproxy-sparse"' \
       '[source.rsproxy-sparse]' 'registry = "sparse+https://rsproxy.cn/index/"' \
       '[registries.rsproxy]' 'index = "sparse+https://rsproxy.cn/index/"' \
       '[net]' 'git-fetch-with-cli = true' \
       > /root/.cargo/config.toml

# focal 自带 protoc 3.6 太老（不认 proto3 optional），换 21.12
RUN curl -fSL https://github.com/protocolbuffers/protobuf/releases/download/v21.12/protoc-21.12-linux-x86_64.zip -o /tmp/protoc.zip \
    && /opt/python312/bin/python3.12 -m zipfile -e /tmp/protoc.zip /usr/local/ \
    && chmod +x /usr/local/bin/protoc && rm /tmp/protoc.zip && protoc --version

ARG GIT_HASH
ARG GIT_HASH_SHORT
ENV GIT_HASH=$GIT_HASH \
    GIT_HASH_SHORT=$GIT_HASH_SHORT

# 拷贝仓库源码
COPY . /src
WORKDIR /src

# 编译 release 二进制；用 BuildKit cache mount 保留中间产物
RUN --mount=type=cache,target=/build/target \
    cargo build --profile=release --no-default-features \
      --features="aws,gcp,azure,jemalloc_replacing_malloc,tokio_console,large-strings" \
    && cp /build/target/release/influxdb3 /influxdb3-bin

# 打包并冒烟
RUN /src/build/package.sh && /src/build/smoke.sh
