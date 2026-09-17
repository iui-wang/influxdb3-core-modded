#!/bin/bash
# 在 influxdb3-focal 容器内运行：对打包产物做冒烟（glibc 2.31 环境）
set -uo pipefail
B=/out/influxdb3-portable/bin/influxdb3
H=http://127.0.0.1:8181
echo '=== 版本 ==='
$B --version || { echo 'VERSION FAIL'; exit 1; }
echo '=== 起 server（--without-auth）==='
$B serve --node-id focaltest --object-store file --data-dir /tmp/focal_smoke --http-bind 127.0.0.1:8181 --without-auth > /tmp/serve.log 2>&1 &
SRV=$!
for i in $(seq 1 30); do curl -s -o /dev/null -w '' $H/health 2>/dev/null && break; sleep 2; done
curl -s $H/health && echo ' <- health'
echo '=== 建库/写入/查询 ==='
$B create database focalsmoke --host $H || echo 'CREATE DB FAIL'
$B write --host $H --database focalsmoke "cpu,host=x usage=0.5 $(date +%s%N)" || echo 'WRITE FAIL'
sleep 1
$B query --host $H --database focalsmoke "SELECT * FROM cpu" || echo 'QUERY FAIL'
echo '=== 魔改验证：建第 6 个库（原版限 5）==='
ok=0
for i in 1 2 3 4 5; do $B create database mdb$i --host $H >/dev/null 2>&1; done
$B create database mdb6 --host $H >/dev/null 2>&1 && ok=1
[ $ok = 1 ] && echo '第 6 个库创建成功（魔改生效）' || echo '第 6 个库失败（魔改未生效!）'
echo '=== server 日志里 python 相关报错 ==='
grep -i -m3 'python\|pyo3' /tmp/serve.log || echo '(无)'
kill $SRV 2>/dev/null
exit $((1-ok))
