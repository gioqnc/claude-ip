#!/usr/bin/env python3
"""PreToolUse hard guard for Claude Code 7900 residential sandbox."""

from __future__ import annotations

import json
import re
import sys


def deny(reason: str) -> int:
    payload = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": f"[7900 沙盒硬拦截] {reason}",
        }
    }
    sys.stdout.write(json.dumps(payload, ensure_ascii=True))
    sys.stdout.flush()
    return 0


def norm_path(p: str) -> str:
    return p.replace("\\", "/").lower()


SENSITIVE_PATH_PATTERNS = [
    (r"google/chrome/user data", "禁止访问日常 Chrome 用户数据目录（含 Cookie/登录态）"),
    (r"microsoft/edge/user data", "禁止访问 Edge 用户数据目录（含 Cookie/登录态）"),
    (r"io\.github\.clash-verge-rev\.clash-verge-rev", "禁止读取 Clash Verge 配置与节点敏感信息"),
    (r"clash-verge\.yaml", "禁止读取 Clash 配置文件"),
    (r"decodo-\d+", "禁止读取家宽代理账密参数文件"),
    (r"friend-clash-", "禁止读取代理配置文件"),
    (r"\.claude/\.credentials\.json", "禁止读取 Claude 本地认证凭据文件"),
]


def check_path(path_str: str) -> str | None:
    if not path_str:
        return None
    np = norm_path(path_str)
    for pattern, msg in SENSITIVE_PATH_PATTERNS:
        if re.search(pattern, np):
            return msg
    return None


COMMAND_RULES = [
    # 1. 跨权限读浏览器 Cookie / 接管宿主浏览器
    (r"--cookies-from-browser", "严禁使用 --cookies-from-browser 读取浏览器 Cookie 数据库"),
    (
        r"(claude-in-chrome|fcoeoabgfenejglbffodgkkbkcdhcgfn|claude_code_browser_extension|claude_browser_extension)",
        "严禁安装、检查或调用 Claude in Chrome 扩展",
    ),
    (
        r"(--remote-debugging-port|\b(?:localhost|127\.0\.0\.1):(?:9222|3456)\b)",
        "严禁通过 CDP / 本地浏览器代理端口接入宿主日常浏览器",
    ),
    # 2. 绕过 7900 代理 / 串用其他端口或控制口 / 本地 DNS socks5://
    (
        r"(--noproxy\b|--proxy\s*(?:=|\s)\s*(?:\"\"|''|none\b|direct\b)|-proxy\s+\$null\b)",
        "严禁清空或绕过 127.0.0.1:7900 代理参数",
    ),
    (
        r"(?:remove-item|del|ri|rm|unset)\b[^\n;]*\b(?:http_proxy|https_proxy|all_proxy)\b|"
        r"\$env:(?:http_proxy|https_proxy|all_proxy)\s*=\s*(?:\"\"|''|\$null)|"
        r"os\.environ\.(?:pop|clear)\([^\)]*proxy",
        "严禁清除或置空代理环境变量",
    ),
    (
        r"\b(?:127\.0\.0\.1|localhost):(?:7890|7891|7897|7898|7899|9097)\b",
        "严禁连接 Clash 其他端口或 9097 控制接口（沙盒仅允许 127.0.0.1:7900）",
    ),
    (
        r"(--proxy\s*(?:=|\s)\s*['\"]?socks5://|--socks5(?!-hostname)\b)",
        "严禁使用本地解析 DNS 的 socks5://，必须使用 socks5h://127.0.0.1:7900",
    ),
    # 3. 本机 IP / 网卡 / 本地 DNS / 原生 UDP / STUN 探测
    (
        r"\b(ipconfig|get-netipaddress|get-netipconfiguration|get-netadapter|"
        r"get-dnsclientserveraddress|get-netroute|arp\s+-a|netstat)\b|"
        r"\broute\s+print\b",
        "严禁查询宿主机真实 IP、网卡、路由或 DNS 配置",
    ),
    (
        r"\b(nslookup|resolve-dnsname|tracert|pathping|test-netconnection|test-connection)\b|"
        r"(?:^|[;&|\n(]\s*)(?:dig|ping)(?:\.exe)?\b|"
        r"\[system\.net\.dns\]",
        "严禁执行绕过代理的本地 DNS 解析或 ICMP/直连探测命令",
    ),
    (
        r"(stun:|stun\.(?:cloudflare\.com|l\.google\.com|sipgate\.net)|rtcpeerconnection)",
        "严禁发起 STUN / WebRTC 原生 UDP 探测",
    ),
    (
        r"\b(ip\.cn|cip\.cc|myip\.ipip\.net|ip\.3322\.net|ip138\.com|2026\.ip138\.com|pv\.sohu\.com/cityjson)\b",
        "严禁访问国内测 IP 接口",
    ),
    # 4. 命令行读取敏感配置文件 / 浏览器数据
    (
        r"(google[/\\]chrome[/\\]user data|microsoft[/\\]edge[/\\]user data|"
        r"clash-verge\.yaml|io\.github\.clash-verge-rev|decodo-\d+|friend-clash-|"
        r"\.claude[/\\]\.credentials\.json)",
        "严禁在命令中读取浏览器用户数据、Clash 配置或敏感凭据文件",
    ),
]


def check_bare_node_network(cmd: str) -> str | None:
    if not re.search(r"\bnode(?:\.exe)?\b", cmd, re.IGNORECASE):
        return None
    # Allow npm / npx / local hyperframes / lemo-opuscar / media-use / statusline scripts
    if re.search(r"\b(npm|npx)\b|statusline\.js|hyperframes|lemo-opuscar|media-use", cmd, re.IGNORECASE):
        return None
    has_net_api = re.search(r"\bfetch\s*\(|https?\.(?:request|get)\s*\(", cmd, re.IGNORECASE)
    has_external_url = re.search(
        r"https?://(?!(?:localhost|127\.0\.0\.1|\[::1\]|::1)\b)", cmd, re.IGNORECASE
    )
    if has_net_api or has_external_url:
        return (
            "本机 Node v22.20.0 原生 fetch/http 默认不读取代理环境变量，"
            "严禁用裸 node 发外网请求；请改用明确走 socks5h://127.0.0.1:7900 的 curl"
        )
    return None


def check_command(cmd: str) -> str | None:
    if not cmd:
        return None
    for pattern, msg in COMMAND_RULES:
        if re.search(pattern, cmd, re.IGNORECASE):
            return msg
    return check_bare_node_network(cmd)


def check_webfetch(url: str) -> str | None:
    if not url:
        return None
    if re.search(
        r"\b(?:127\.0\.0\.1|localhost):(?:7890|7891|7897|7898|7899|9097|9222|3456)\b",
        url,
        re.IGNORECASE,
    ):
        return "严禁访问 Clash 本地控制/其他代理或浏览器调试端口"
    if re.search(
        r"\b(ip\.cn|cip\.cc|myip\.ipip\.net|ip\.3322\.net|ip138\.com|2026\.ip138\.com)\b",
        url,
        re.IGNORECASE,
    ):
        return "严禁访问国内测 IP 站点"
    return None


def main() -> int:
    try:
        sys.stdin.reconfigure(encoding="utf-8", errors="replace")
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:  # noqa: BLE001
        pass

    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
    except Exception as exc:  # noqa: BLE001
        return deny(f"Hook 解析输入失败，按安全策略拒绝执行: {exc}")

    tool_name = str(data.get("tool_name") or "")
    tool_input = data.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        tool_input = {}

    if "chrome" in tool_name.lower():
        return deny(f"严禁调用浏览器扩展/接管工具: {tool_name}")

    if tool_name in ("Bash", "PowerShell"):
        reason = check_command(str(tool_input.get("command") or ""))
        if reason:
            return deny(reason)
    elif tool_name in ("Read", "Edit", "Write"):
        reason = check_path(str(tool_input.get("file_path") or ""))
        if reason:
            return deny(reason)
    elif tool_name in ("Grep", "Glob"):
        for key in ("path", "pattern"):
            reason = check_path(str(tool_input.get(key) or ""))
            if reason:
                return deny(reason)
    elif tool_name == "WebFetch":
        reason = check_webfetch(str(tool_input.get("url") or ""))
        if reason:
            return deny(reason)

    return 0


if __name__ == "__main__":
    sys.exit(main())
