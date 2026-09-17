# InfluxDB 3 Core Modded

这是 [InfluxDB 3 Core](https://github.com/influxdata/influxdb) v3.11.4 的魔改版，仅提高 database / table 数量的硬限制，便于个人/小流量场景使用。

| 限制项 | 原版 Core | 魔改版 |
|---|---:|---:|
| 单个节点 database 上限 | 5 | 100 |
| 单个节点 table 总上限 | 2,000 | 10,000 |
| 每表列数上限 | 500 | 500（未改动） |

> 说明：table 上限是**全 server 跨库共享的总池**，删除 database 会立即释放对应 table 配额。

## 唯一改动

仅修改 `influxdb3/src/commands/serve.rs` 两个常量：

```rust
const CORE_NUM_DBS_LIMIT: usize = 100;
const CORE_NUM_TABLES_LIMIT: usize = 10_000;
```

完整补丁见 [`build/serve.rs.patch`](build/serve.rs.patch)。

## 直接编译（不用 Docker）

以下步骤在 Ubuntu 22.04/24.04 x86_64 验证通过，其他 Linux 发行版原理相同。

### 1. 系统依赖

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential lld pkg-config cmake curl ca-certificates xz-utils git \
  libssl-dev zlib1g-dev libffi-dev libsqlite3-dev libbz2-dev liblzma-dev \
  libreadline-dev libncursesw5-dev uuid-dev tk-dev
```

### 2. 安装 protoc ≥ 21.12

Ubuntu 20.04/22.04 自带 protoc 太老，不认 `proto3 optional`，需要手动安装 21.12+：

```bash
PROTOC_VERSION=21.12
curl -fSL "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip" -o /tmp/protoc.zip
sudo unzip -o /tmp/protoc.zip -d /usr/local/
protoc --version
```

### 3. 安装 Python 3.12（共享库，PyO3 需要）

InfluxDB 3 的 processing engine 通过 PyO3 链接 `libpython`，编译和运行都需要 Python 3.12 的共享库。

```bash
PY_VER=3.12.11
curl -fSL "https://www.python.org/ftp/python/${PY_VER}/Python-${PY_VER}.tgz" -o /tmp/py.tgz
tar -C /tmp -xf /tmp/py.tgz
cd /tmp/Python-${PY_VER}
./configure --enable-shared --prefix=/opt/python312 \
  LDFLAGS="-Wl,-rpath,/opt/python312/lib"
make -j"$(nproc)"
sudo make install
```

### 4. 安装 Rust 1.97.1

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.97.1
source "$HOME/.cargo/env"
rustc --version
```

### 5. 克隆并编译

```bash
git clone https://github.com/iui-wang/influxdb3-core-modded.git
cd influxdb3-core-modded
export PYO3_PYTHON=/opt/python312/bin/python3.12
cargo build --profile=release --no-default-features \
  --features="aws,gcp,azure,jemalloc_replacing_malloc,tokio_console,large-strings"
```

编译完成后二进制在：

```bash
./target/release/influxdb3
```

### 6. 运行

```bash
./target/release/influxdb3 serve \
  --node-id mynode \
  --object-store file \
  --data-dir ./data \
  --without-auth
```

默认 HTTP API 监听 `http://127.0.0.1:8181`。生产环境建议去掉 `--without-auth`，使用 `./target/release/influxdb3 create token --admin` 创建管理员 token。

## Docker 编译（便携包）

仓库提供 Ubuntu 20.04 容器化构建，目标 glibc ≥ 2.31，输出自包含便携包。

```bash
docker build \
  --build-arg GIT_HASH=$(git rev-parse HEAD) \
  --build-arg GIT_HASH_SHORT=$(git rev-parse --short HEAD) \
  -t influxdb3-modded .
```

构建流程：

1. 在容器内编译 release 二进制。
2. 运行 [`build/package.sh`](build/package.sh) 把二进制、`libpython3.12.so.1.0` 和标准库打包到 `/out/influxdb3-portable`。
3. 运行 [`build/smoke.sh`](build/smoke.sh) 做建库/写入/查询/第 6 库验证。

导出便携包：

```bash
# 创建临时容器，仅复制产物
docker create --name tmp-influxdb3 influxdb3-modded
docker cp tmp-influxdb3:/out/influxdb3-portable-focal-v3.11.4.tar.gz ./
docker rm tmp-influxdb3

tar -xzf influxdb3-portable-focal-v3.11.4.tar.gz
cd influxdb3-portable
bin/influxdb3 serve --node-id mynode --object-store file --data-dir ./data --without-auth
```

## 验证魔改生效

```bash
# 先启动 server，然后创建 6 个库
for i in 1 2 3 4 5 6; do
  ./target/release/influxdb3 create database "db$i" --host http://127.0.0.1:8181
done
```

原版 Core 在第 6 个库会被拒绝；魔改版可成功创建，上限精确到 100 个库 / 10,000 张表。

## 文件说明

| 文件 | 用途 |
|---|---|
| `build/serve.rs.patch` | 魔改补丁（供手工 apply 或查阅） |
| `build/package.sh` | 容器内打包便携包 |
| `build/smoke.sh` | 容器内冒烟测试 |
| `Dockerfile` | Ubuntu 20.04 编译镜像 |

## 许可

本仓库基于 InfluxDB 官方源码修改，原代码采用 [MIT](LICENSE-MIT) 或 [Apache-2.0](LICENSE-APACHE) 双许可，保持不变。
