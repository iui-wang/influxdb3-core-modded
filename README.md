# influxdb3-core-modded

InfluxDB 3 Core 的魔改版构建：提高 database / table 数量硬限制。

基于官方源码 `influxdata/influxdb` @ `693b1fd1b9`（v3.11.0-nightly，Apache-2.0 / MIT 双许可，原许可条款不变），仅修改两个常量（见 `build/serve.rs.patch`）：

| 常量 | 原版 | 魔改版 |
|---|---|---|
| `CORE_NUM_DBS_LIMIT` | 5 | 100 |
| `CORE_NUM_TABLES_LIMIT` | 2000 | 10000 |

注意：table 限制是**全 server 跨库共享的总池**（所有 database 共用 10000 张表），不是每库配额；删除 database 会立即释放配额。列数限制（每表 500 列）未动。

## 下载

见 [Releases](../../releases)。`influxdb3-portable-focal.tar.gz` 为自包含便携包：

- `bin/influxdb3` — 主程序（官方 release profile 编译，fat LTO）
- `lib/` — 内置 libpython3.12 + Python 3.12 标准库（processing engine 硬依赖），rpath 已设为相对路径

**运行要求**：x86_64 Linux，glibc ≥ 2.31（Ubuntu 20.04+）。解压即用，无需安装任何依赖。

```bash
tar -xzf influxdb3-portable-focal.tar.gz
cd influxdb3-portable
sha256sum -c ../influxdb3-portable-focal.tar.gz.sha256  # 先校验（对 tarball 本身）
bin/influxdb3 serve --node-id mynode --object-store file --data-dir ./data --without-auth
```

生产使用建议去掉 `--without-auth` 并改用 `create token --admin` 启用认证。

## 复现构建

`build/` 目录含完整构建资产（Ubuntu 20.04 容器内编译，对齐 glibc 2.31）：

- `Dockerfile` — 构建环境（Rust 1.97.1 + Python 3.12 + protoc 21.12）
- `serve.rs.patch` — 魔改补丁
- `package.sh` — 打便携包（内置 libpython、设 rpath）
- `smoke.sh` — 冒烟测试（建库/写入/查询/第 6 库验证）

## 已验证

- 建库 / 写入 / SQL 查询正常；第 6 个 database 创建成功（原版第 6 个即被拒）
- database 上限精确命中 100（第 101 个被拒）；table 上限精确命中 10000
- 批量写入原子性：超限批次整体回滚，不留残表
