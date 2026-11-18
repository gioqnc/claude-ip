# Claude CLI 专属家宽防泄露隔离沙盒方案

适用于需要使用 **Claude Code CLI**，且要求流量：
1. **100% 走专属家宽 IP**，绝不回落到真实网络。
2. **电脑其余软件正常走普通 VPS 或国内直连**，不消耗昂贵家宽流量。
3. **彻底物理阻断 WebRTC STUN 探测、UDP DNS 泄露、IPv6 绕过**。
4. **Kill Switch 机制常驻底层**：即使代理软件意外崩溃，Claude 会立刻物理断网，绝不暴露真实 IP。

---

## 目录结构说明

- `claude-safe.bat`: 启动脚本入口（双击拉起沙盒窗口）。
- `claude-safe.ps1`: 核心启动脚本（注入专属代理环境变量、调用 API 检测当前家宽 IP 与 ISP、安全熔断）。
- `setup-firewall.ps1`: Windows 高级防火墙（WFP）规则部署脚本。
- `一键配置防火墙(管理员).bat`: 右键以管理员运行即可一键部署防火墙拦截规则，并在桌面生成快捷方式。
- `clash-config-example.yaml`: Clash Verge Rev / Mihomo 配置文件模板（包含专属 `7900` 监听端口配置）。

---

## 新电脑部署指南（3 步走）

### 1. 配置 Clash
1. 将 `clash-config-example.yaml` 中的节点信息换为你自己的 VPS 与家宽账号，导入 Clash Verge Rev。
2. 核心是在配置中开启 `listeners`：
   ```yaml
   listeners:
     - name: claude-isp-mixed
       type: mixed
       listen: 127.0.0.1
       port: 7900
       proxy: 🏠 家宽分流
   ```
3. 刷新并加载该配置。

### 2. 部署底层防火墙规则（一次性）
1. 右键点击 **`一键配置防火墙(管理员).bat`**，选择 **“以管理员身份运行”**。
2. 脚本会自动锁定 `claude.exe` 与 `node.exe`：
   - 阻断所有外部直接连接（Direct Internet）；
   - 阻断所有 UDP 出站（绝无 WebRTC/STUN 泄露）；
   - 仅放行去往 `127.0.0.1:7900` 的 TCP 流量。
3. 执行完毕后，会在新电脑桌面上自动生成 **`Claude Safe`** 快捷方式。

### 3. 日常使用
- 平时正常上网，电脑其他程序继续走 VPS。
- 需要使用 Claude 时，**双击桌面上的 `Claude Safe` 快捷方式**。
- 窗口启动时会自动请求 `ipinfo` 检测出口 IP、国家与住宅运营商（ISP）：
  - 若为正常家宽：显示绿色提示并放行启动 Claude；
  - 若代理未开或属于中国大陆 IP：**直接红字熔断退出，杜绝封号**。

---

## 登录授权（WebRTC 防泄露）

首次使用执行 `claude login` 时：
1. 终端打印出的登录 URL，**不要直接用默认浏览器打开**。
2. 复制该链接，在你的**指纹浏览器**（确保 WebRTC 设为替换/禁用，且代理配置为 `127.0.0.1:7900`）中打开并完成授权。
