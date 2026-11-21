# Claude CLI 专属家宽防泄露隔离沙盒方案

适用于需要使用 **Claude Code CLI** 与指纹浏览器，且希望网络结构极简、无需维护繁琐分流规则的场景：

1. **沙盒与 `7900` 端口 100% 走专属家宽 IP**（`select` 手动模式不回落），绝不暴露真实 IP 或回退到 VPS。
2. **电脑其余软件日常走普通 VPS + 国内直连**：不消耗昂贵家宽流量，也不必维护上百条域名分流规则。
3. **提供桌面一键切换按钮**：主浏览器某网页需要临时用家宽时，一键把海外默认出口切换为家宽（保持 `rule` 模式，微信/B站等国内软件继续直连不烧家宽流量），用完再点一下切回 VPS。
4. **物理防泄露与 Kill Switch**：防火墙底层阻断 `claude.exe` 的 UDP、直连公网、Clash Fake-IP TUN 网段及其他非 `7900` 端口，只放行 `127.0.0.1:7900`。

---

## 目录结构说明

- `claude-safe.bat` / `claude-safe.ps1`：沙盒启动入口（仅对当前窗口注入 `127.0.0.1:7900` 代理与 `NO_PROXY=localhost,127.0.0.1,::1`，启动前调用 `ipinfo.io` 校验出口 IP 与国家，非海外/不可达立即熔断退出；兼容 npm 全局安装原生 `claude.exe` 与 WinGet 路径）。
- `claude` / `claude.cmd` / `claude.ps1`：全局 `claude` 命令包装入口；将该目录放到用户 `PATH` 中 `npm-global` 之前，即可在任意项目文件夹终端直接敲 `claude` 自动进入 `7900` 家宽沙盒，并支持同时多开多个互不干扰的 Claude 窗口。
- `toggle-proxy.bat` / `toggle-proxy.ps1`：日常海外出口一键切换脚本（通过 Clash `127.0.0.1:9097` 控制接口在 `🇺🇸 US-自建` ↔ `🏠 家宽分流` 间切换，自动保持 `rule` 模式、弹出系统通知，并只刷新经由 `节点选择` 的旧连接，不影响 `7900` 沙盒与国内直连）。
- `setup-firewall.ps1`：Windows 防火墙规则部署脚本（锁定 `claude.exe`，并在桌面生成 `Claude Safe` 与 `切换家宽出口` 快捷方式）。
- `一键配置防火墙-管理员.bat`：管理员提权安装入口（文件名不含括号，避免 Windows 右键“以管理员身份运行”触发 `cmd.exe /C` 括号截断问题；支持直接双击或右键管理员运行）。
- `clash-config-example.yaml`：极简 Clash Verge Rev / Mihomo 配置模板（含 `7900` 独立监听端口、`9097` 控制接口，以及 `claude.ai` / `anthropic.com` 等域名强制走 `🏠 家宽分流` 的防串 IP 规则）。
- `claude-config/`：Claude Code 侧的**工具级硬拦截 + 全局记忆防泄露模板**：
  - `hooks/sandbox-guard.py`：`PreToolUse` 硬拦截脚本，在工具执行前直接拦截 `--cookies-from-browser`、`Claude in Chrome`/CDP、读浏览器 `User Data` / Clash 配置、`--noproxy`/清代理变量、访问 Clash 其他端口与 `9097`、本地 DNS/IP 探测（`ipconfig`/`nslookup`/STUN/国内测 IP）及不认代理变量的裸 `node` 外网请求；
  - `settings.sandbox-snippet.json`：`~/.claude/settings.json` 中的 `permissions.deny` 与 `hooks.PreToolUse` 配置片段模板；
  - `CLAUDE.sandbox-rules.md`：写入 `~/.claude/CLAUDE.md` 的全局沙盒防泄露铁律；
  - `memory/sandbox-ip-dns-isolation.md` & `memory/agy-sandbox-verification.md`：项目自动记忆卡模板与 `agy` 实测放行记录。

---

## 复用本方案：接入你自己的家宽与日常节点

本仓库不含任何真实节点账密，且所有脚本与具体代理商**完全解耦**——脚本只依赖本地端口与策略组约定，替换为你自己的节点即可直接使用：

### 只需替换 1 处（Clash 配置）
复制一份 `clash-config-example.yaml` 并修改：
1. **替换日常海外节点**：将 `proxies` 中的 `🇺🇸 US-自建` 替换为你的日常 VPS 或机场节点（名字可任意自定义，不必保留 `🇺🇸 US-自建`，`toggle-proxy.ps1` 会自动识别 `节点选择` 中除 `🏠 家宽分流` 外的第一个日常节点；也可通过环境变量 `CLAUDE_SAFE_VPS_NODE` 指定）。
2. **替换专属家宽节点**：将 `proxies` 中的 `🏠 Decodo-10001` / `10002` 删除，填入**你自己的家宽节点**（SOCKS5 / HTTP / VLESS / 链式代理或直连家宽均可）。
3. **更新家宽策略组**：将 `proxy-groups` 下 `🏠 家宽分流` 中的 `proxies` 列表改为你刚填入的家宽节点名，并**保持 `type: select`**（断流即断网，不自动回落）。
4. **保持以下 4 项约定不变**，即可零修改直接运行全部脚本：
   - `listeners` 监听 `127.0.0.1:7900` 且 `proxy: 🏠 家宽分流`
   - `external-controller: 127.0.0.1:9097`
   - 策略组名 `节点选择`（包含你的日常节点与 `🏠 家宽分流`）
   - 策略组名 `🏠 家宽分流`（`type: select`）

> 若你已有现成机场订阅配置，只需在你的 Clash 配置（或覆写脚本）中补入上述 `listeners`（`7900`）、`🏠 家宽分流` 策略组、`external-controller: 127.0.0.1:9097` 及 5 条 Claude/Anthropic 域名规则，并将 `🏠 家宽分流` 加入 `节点选择` 组即可。

---

## 部署指南（3 步走）

### 1. 配置 Clash Verge Rev
1. 将 `clash-config-example.yaml` 中的节点信息替换为自己的 VPS 与家宽账号，导入 Clash Verge Rev。
2. 核心配置要点：
   - `listeners` 开启 `127.0.0.1:7900` 绑定 `🏠 家宽分流`（`type: select`）；
   - `节点选择` 中放入 `[🇺🇸 US-自建, 🏠 家宽分流]`；
   - `rules` 仅保留局域网/国内直连、Claude/Anthropic 专属域名走 `🏠 家宽分流` 与 `MATCH,节点选择`；
   - 开启 `external-controller: 127.0.0.1:9097` 供一键切换按钮调用。
3. 刷新并加载该配置（建议同时开启 Clash TUN 模式与防泄漏 Kill Switch）。

### 2. 部署底层防火墙规则（一次性）
1. 双击或右键 **`一键配置防火墙-管理员.bat`** → **“以管理员身份运行”**。
2. 脚本会自动锁定原生 `claude.exe`：
   - 阻断所有 UDP 出站（防 QUIC / WebRTC / STUN / UDP DNS 泄露）；
   - 阻断公网 TCP 直连；
   - 阻断 Clash Fake-IP 网段（`198.18.0.0/15`），防止未走代理环境变量时通过 TUN 回落到 VPS；
   - 阻断 `127.0.0.1` 的 Clash 其他常见端口（`7890/7891/7897/7898/7899`）；
   - 仅放行去往 `127.0.0.1:7900` 的 TCP 流量。
   > 注：npm 安装的 Claude Code v2+ 使用内置原生 `claude.exe`（不经过系统 `node.exe`），因此不再全局封锁 `node.exe`，避免影响 `npm` / `gemini` 等其他 Node 工具。
3. 执行完毕后会在桌面生成 **`Claude Safe`** 与 **`切换家宽出口`** 两个快捷方式。

### 3. 日常使用
- **平时上网**：无需切换，国内直连、海外默认走 `🇺🇸 US-自建` VPS。
- **使用 Claude Code CLI**：
  - 双击桌面 **`Claude Safe`**；
  - 或将本仓库目录放到用户 `PATH` 中 `npm-global` 之前后，在**任意项目文件夹**终端（CMD / PowerShell / Git Bash）直接输入 `claude` 启动，支持同时多开多个窗口；窗口会先通过 `7900` 核验出口 IP 与运营商，确认非中国大陆 IP 后再以当前目录拉起 `claude.exe`。
- **主浏览器某网页临时用家宽**：双击桌面 **`切换家宽出口`**，除国内直连与特殊规则外，海外流量立刻全切到 `🏠 家宽分流`；用完再双击一次切回 VPS（若需在普通浏览时同时隔离出纯家宽窗口，也可直接在指纹浏览器中配置 `127.0.0.1:7900`）。

---

## 登录授权（WebRTC 防泄露）

首次使用执行 `claude login` 时：
1. 终端打印出的登录 URL，**不要直接用未隔离的默认浏览器打开**。
2. 复制该链接，在你的**指纹浏览器**（确保 WebRTC 设为替换/禁用，且代理配置为 `127.0.0.1:7900`）中打开并完成授权。

---

## Claude Code 防泄露硬拦截与记忆规则

在换新电脑或重装环境时，可将 `claude-config/` 中的配置同步到 `~/.claude/`：
1. 将 `claude-config/hooks/sandbox-guard.py` 复制到 `~/.claude/hooks/sandbox-guard.py`；
2. 将 `claude-config/settings.sandbox-snippet.json` 中的 `permissions.deny` 与 `hooks.PreToolUse` 合并进 `~/.claude/settings.json`（并填写本机 `python.exe` 与用户目录绝对路径）；
3. 将 `claude-config/CLAUDE.sandbox-rules.md` 写入 `~/.claude/CLAUDE.md`；
4. 按需将 `claude-config/memory/*.md` 复制到对应项目的 `~/.claude/projects/<project>/memory/` 并在 `MEMORY.md` 索引。
