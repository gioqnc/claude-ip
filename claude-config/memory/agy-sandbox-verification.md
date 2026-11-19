---
name: agy-sandbox-verification
description: Antigravity CLI（agy）在 7900 代理沙盒内出站连接实测记录
metadata:
  node_type: memory
  type: reference
  modified: 2026-11-19T20:26:00+08:00
---

**沙盒已实测放行**（2026-11-19）：对 `agy.exe`（v1.5.12）注入 `7900` 环境变量（`HTTP_PROXY` / `HTTPS_PROXY` = `http://127.0.0.1:7900`、`ALL_PROXY` = `socks5h://127.0.0.1:7900`）做无头实测与进程树套接字追踪：

- 全部 Google API / 更新请求均通过 `HTTPS CONNECT` 经 `127.0.0.1:7900` 走向 `🏠 家宽分流`；
- 进程树内未观测到直连外网、`198.18.x.x` Fake-IP TUN 旁路或 UDP 端点；
- 在家宽流量不限量的前提下允许在沙盒内调用 `agy`，但不得额外加 `-Proxy` 绕过参数。
