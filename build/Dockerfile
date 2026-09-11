# syntax=docker/dockerfile:1
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

# 国内 apt 镜像
RUN sed -i 's|archive.ubuntu.com|mirrors.ustc.edu.cn|g; s|security.ubuntu.com|mirrors.ustc.edu.cn|g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential lld pkg-config protobuf-compiler libprotobuf-dev cmake curl ca-certificates xz-utils git \
       libssl-dev zlib1g-dev libffi-dev libsqlite3-dev libbz2-dev liblzma-dev libreadline-dev libncursesw5-dev uuid-dev tk-dev patchelf \
    && rm -rf /var/lib/apt/lists/*

# Python 3.12 源码编译（focal 源里没有），--enable-shared 供 pyo3 链接
RUN curl -fSL https://mirrors.huaweicloud.com/python/3.12.11/Python-3.12.11.tgz -o /tmp/py.tgz \
    && tar -C /tmp -xf /tmp/py.tgz \
    && cd /tmp/Python-3.12.11 \
    && ./configure --enable-shared --prefix=/opt/python312 LDFLAGS="-Wl,-rpath,/opt/python312/lib" \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/py.tgz /tmp/Python-3.12.11

# Rust 1.97.1，走 rsproxy 镜像
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

# focal 自带 protoc 3.6 太老（不认 proto3 optional），换 21.12（宿主机从 npmmirror 下好），/usr/local/bin 优先于 /usr/bin
COPY protoc.zip /tmp/protoc.zip
RUN /opt/python312/bin/python3.12 -m zipfile -e /tmp/protoc.zip /usr/local/ \
    && chmod +x /usr/local/bin/protoc && rm /tmp/protoc.zip && protoc --version

# 宿主机的 cargo 缓存直接带进来（git 依赖与 867 个 crate 全部离线命中）
COPY cargo-cache/git /root/.cargo/git
COPY cargo-cache/registry /root/.cargo/registry

COPY src /src
WORKDIR /src
RUN CARGO_NET_OFFLINE=true cargo fetch --locked
# target 用 BuildKit cache mount，失败重跑不丢已编产物；编完把二进制拷出 cache 层
RUN --mount=type=cache,target=/build/target \
    CARGO_NET_OFFLINE=true cargo build --profile=release --no-default-features \
      --features="aws,gcp,azure,jemalloc_replacing_malloc,tokio_console,large-strings" \
    && cp /build/target/release/influxdb3 /influxdb3-bin
