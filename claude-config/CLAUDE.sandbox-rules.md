## 沙盒与防 IP / DNS 泄露铁律（最高优先级）

所有网络行为与子进程调用必须 **100% 严格落在家宽代理沙盒（`127.0.0.1:7900`）内**，绝不允许发生任何真实 IP 暴露、DNS 泄露或跨权限读取宿主信息：

1. **严禁脱离 `7900` 家宽沙盒**：
   - 任何联网命令或脚本（`curl`、`python`、`node`、`yt-dlp`、`Invoke-WebRequest` 等）必须继承并使用 `127.0.0.1:7900`（且域名解析必须走远程代理如 `socks5h://127.0.0.1:7900` 或 HTTP `CONNECT`），**严禁**清除/覆盖代理环境变量，**严禁**使用 `--proxy ""`、`--noproxy`、直连物理网卡，或连接 Clash 其他端口（`7890/7891/7897/7898/7899`）。
   - **Node.js 与正常创作工具白名单**：本机 `node`（`v22.20.0` 等 `v22.21` 以前版本）原生 `fetch()`/`http`/`https` 默认不读取代理环境变量，**严禁**自己手写裸 `node` 联网脚本发起任意外网请求（需要轻量外网请求优先用明确走 `socks5h://127.0.0.1:7900` 的 `curl`）。**但以下正常本地开发与视频创作工具明确放行、不要因内部可能走系统 Clash TUN 而停工**：**HyperFrames**（含无头 Chrome 渲染、加载 `jsdelivr` 等公开 CDN、`hyperframes add`、`media-use`）、**Lemo-Opuscar**、**`npm`/`npx`**、**`agy`**、**`ffmpeg`**（电脑全局开着 Clash `Mihomo` TUN `fake-ip` + `clash-guard` 断网保护，这些工具不连 Anthropic 账号也不会暴露真实国内 IP；家宽不限流量）。
   - **严禁**安装、启用、检查或调用 `Claude in Chrome` 扩展，**严禁**通过 CDP、浏览器自动化或任何方式接入宿主日常 Chrome / Edge（日常浏览器走 Clash `rule` 分流且包含国内 `DIRECT` 直连与非家宽节点，会直接脱离 `7900` 沙盒）。
   - **严禁**发起任何原生 UDP 请求、WebRTC/STUN 探测或绕过代理的本地 DNS 解析命令（如 `nslookup`、`Resolve-DnsName`、`dig`、`ping`、`tracert`、原始 UDP/TCP socket 直连等），防止走本地网卡 DNS。
2. **严禁读取任何可能拿到真实 IP 或越权凭据的内容**：
   - **严禁**运行或读取暴露本机真实 IP、网卡、路由、本地 DNS 或代理节点配置的信息（如 `ipconfig`、`Get-NetIPAddress`、`Get-NetAdapter`、`Get-DnsClientServerAddress`、`route`、`netstat`、`clash-verge.yaml`、代理日志、以及访问国内测 IP/风控接口）。
   - **严禁**跨权限读取任何浏览器的 Cookie、密码或本地会话数据库（如 `yt-dlp --cookies-from-browser`、Chrome/Edge 的 `Cookies` / `Login Data` / `Local State` 等）。
3. **涉及国内站点或需宿主登录态的内容如何处理**：
   - 凡遇到需要国内直连 IP 或浏览器登录态才能访问的内容（如抖音、小红书、B站需登录内容、X 需登录长文等），**一律不要在沙盒里带 Cookie 硬抓、不要尝试切直连、也不要接管宿主机浏览器**——直接停止并请用户自行下载/保存/截图到本地目录后再读取本地文件。
   - 除上述白名单创作工具外，若某项操作涉及接入日常浏览器、读 Cookie、查询本机 IP/DNS 或显式绕过代理，**直接停止并告知用户风险，绝不自行试探执行**。
