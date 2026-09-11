# InfluxDB 3 Core

Open source time series database written in Rust, built on Apache Arrow, DataFusion, and Parquet. This repo's `main` branch is v3 Core; v1/v2 live on separate branches. Product overview: `README.md`.

## Layout

- `influxdb3/` — the `influxdb3` binary (default workspace member) and its library `influxdb3_lib`. Entry point `influxdb3/src/main.rs` → `influxdb3_lib::startup()`.
- CLI subcommands are split: local ones (`serve`, `create`, `show`, `delete`, `update`) live in `influxdb3/src/commands/`; shared ones (`query`, `write`, `test`, `enable`, `disable`, `install`, `debug`) live in the `influxdb3_commands` crate.
- `influxdb3_*/` — v3 server crates: catalog, WAL, write path, query executor, processing engine, HTTP server, CLI config blocks, telemetry, test helpers.
- `core/` — shared crates inherited from the IOx codebase: line protocol parsing, DataFusion query planning, Parquet, object store wrappers, observability.
- Full member list: `[workspace].members` in `Cargo.toml`.

## Architecture

- Write path (`influxdb3_write`, `influxdb3_wal`): incoming line protocol goes into the WAL and an in-memory queryable buffer; periodic WAL snapshots convert buffered data into Parquet files persisted to object storage (S3/Azure/GCS) or local disk.
- Query path: SQL, InfluxQL, and Flight SQL planned and executed with DataFusion (`influxdb3_query_executor`, `core/iox_query*`).
- Processing engine: embedded Python VM (PyO3) for plugins and triggers (`influxdb3_processing_engine`, `influxdb3_py_api`).
- HTTP API served by `influxdb3_server`, default port 8181.

## Common commands

- Build: `cargo build` (builds `influxdb3`). Profiles `release`, `quick-release`, `quick-bench` are defined in `Cargo.toml`; details in `CONTRIBUTING.md` and `PROFILING.md`.
- Test: `cargo nextest run --workspace` (requires `cargo-nextest`). End-to-end tests live in `influxdb3/tests/` and spin up a real server; show its logs with `TEST_LOG= cargo nextest run -p influxdb3 --nocapture`.
- Lint/format: `cargo fmt --all` and `cargo clippy --all-targets --workspace -- -D warnings`. CI enforces both.

## Constraints

- Rust toolchain is pinned in `rust-toolchain.toml` (edition 2024); workspace lints deny `todo!`, `dbg!`, `unreachable_pub`, and missing `Debug`/`Copy` impls.
- System dependencies: `protoc` and `python3` with dev headers — the binary is dynamically linked to the `libpython` PyO3 finds at build time, and the matching Python runtime must be present when it runs (details in `README_processing_engine.md`).
- DataFusion comes from InfluxData's fork via `[patch.crates-io]` in `Cargo.toml`. When adding a `datafusion-*` dependency, add it to the patch list too, or `Cargo.lock` ends up with both the fork and the crates.io release.
- `serde_json` is pinned to `1.0.127` to avoid a conflict with `core`; see the comment in `Cargo.toml`.
- Commit messages follow Conventional Commits (`CONTRIBUTING.md`).

## More docs

- `CONTRIBUTING.md` — tests, logging in tests, build profiles, PR process.
- `README_processing_engine.md` — Python plugin/trigger engine internals and system requirements.
- `PROFILING.md` — profiling the binary on macOS/Linux.
- `RELEASE.md` — release process.
