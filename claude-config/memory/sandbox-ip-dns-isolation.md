---
name: sandbox-ip-dns-isolation
description: 严禁脱离 7900 家宽沙盒、严禁读取浏览器 Cookie 或任何可能暴露真实 IP / DNS 的本地信息
metadata:
  node_type: memory
  type: feedback
  modified: 2026-11-19T20:03:00+08:00
---

1. 所有联网工具和子进程必须 100% 落在 `127.0.0.1:7900`（远程 DNS 代理如 `socks5h://`），严禁清除代理变量、`--proxy ""`、`--noproxy`、走其他 Clash 端口、直连或发起原生 UDP / 本地 DNS 查询（`nslookup`/`Resolve-DnsName`/`ping`/`dig` 等）。
2. 本机 `node`（`v22.20.0`）原生 `fetch`/`http` 不认代理环境变量，严禁手写裸 `node` 发任意外网请求；**但正常创作与开发工具明确白名单放行**：HyperFrames（含无头 Chrome 加载公开 CDN、`hyperframes add`、`media-use`）、Lemo-Opuscar、`npm`/`npx`、`agy`、`ffmpeg` 均正常使用，不要因内部可能走 Clash TUN（`fake-ip`）而停工。
3. 严禁安装/调用 `Claude in Chrome` 或通过 CDP/自动化接入日常 Chrome/Edge，严禁使用 `--cookies-from-browser` 等越权读取浏览器 Cookie/登录库。
4. 严禁读取或执行可能暴露宿主真实 IP、网卡/DNS 配置或 Clash 配置的命令与文件（`ipconfig`、`Get-NetIPAddress`、`Get-DnsClientServerAddress`、`clash-verge.yaml`、国内测 IP 接口等）。
5. 遇到抖音、X 需登录内容等受阻场景，直接请用户自行保存/截图到本地文件后再处理，不跨权限试探。

**Why:** 2026-11-19 明确要求零 IP/DNS 泄露：日常浏览器走 Clash `rule` 分流（含国内直连和 VPS）会脱离 `7900` 家宽沙盒；在沙盒里读浏览器 Cookie 拉国内站点不仅越权，还会拿国内登录态从美国家宽出口请求。

**How to apply:** 完整全局红线见 `~/.claude/CLAUDE.md`，在所有任务与工具调用前强制执行；无法确认完全走 `7900`（含远程 DNS）的操作一律停止。
