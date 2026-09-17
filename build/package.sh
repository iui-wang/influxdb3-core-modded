#!/bin/bash
# 在 influxdb3-focal 容器内运行：打自包含便携包到 /out
set -euo pipefail
PKG=/out/influxdb3-portable
mkdir -p $PKG/bin $PKG/lib
cp /influxdb3-bin $PKG/bin/influxdb3
cp -a /opt/python312/lib/libpython3.12.so.1.0 $PKG/lib/
# 精简 stdlib：去 __pycache__ / test / tests
cp -a /opt/python312/lib/python3.12 $PKG/lib/
find $PKG/lib/python3.12 -type d -name '__pycache__' -prune -exec rm -rf {} +
find $PKG/lib/python3.12 -type d \( -name 'test' -o -name 'tests' \) -prune -exec rm -rf {} +
patchelf --set-rpath '$ORIGIN/../lib' $PKG/bin/influxdb3
echo '=== rpath ==='; patchelf --print-rpath $PKG/bin/influxdb3
echo '=== NEEDED ==='; readelf -d $PKG/bin/influxdb3 | grep NEEDED
echo '=== GLIBC 最高需求 ==='; readelf -V $PKG/bin/influxdb3 | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -3

# 打 tarball
TARBALL=/out/influxdb3-portable-focal-v3.11.4.tar.gz
tar -czf "$TARBALL" -C /out influxdb3-portable
sha256sum "$TARBALL" > "$TARBALL.sha256"

du -sh $PKG "$TARBALL"
