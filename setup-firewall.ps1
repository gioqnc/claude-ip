# 需要以管理员权限运行（用于一键部署 Windows 内核级防火墙规则）
# 规则效果：
# 1. 彻底切断 claude.exe 的一切公网直连与 TUN 绕过（防代理崩溃或规则切换时回落）
# 2. 彻底阻断 UDP 流量（防 WebRTC STUN / QUIC / 本地 DNS 泄露）
# 3. 禁止 claude.exe 访问 Clash 其他日常端口（7890/7891/7897/7898/7899）
# 4. 唯一外网代理白名单：仅允许向 127.0.0.1:7900（专属家宽代理端口）发起 TCP 连接

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[错误] 请右键 一键配置防火墙-管理员.bat 选择“以管理员身份运行”！" -ForegroundColor Red
    pause
    exit 1
}

$ClaudeExe = $null
$candidates = @(
    "$env:USERPROFILE\npm-global\node_modules\@anthropic-ai\claude-code\bin\claude.exe",
    "$env:APPDATA\npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Anthropic.ClaudeCode_Microsoft.Winget.Source_8wekyb3d8bbwe\claude.exe"
)
$cmd = Get-Command claude -ErrorAction SilentlyContinue
if ($cmd -and $cmd.Source) {
    $cmdDir = Split-Path -Parent $cmd.Source
    $candidates = @((Join-Path $cmdDir "node_modules\@anthropic-ai\claude-code\bin\claude.exe")) + $candidates
}
foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) {
        $ClaudeExe = $c
        break
    }
}
if (-not $ClaudeExe) {
    $exeCmd = Get-Command claude.exe -ErrorAction SilentlyContinue
    if ($exeCmd) { $ClaudeExe = $exeCmd.Source }
}

Write-Host "正在部署 Windows 防火墙沙盒拦截规则..." -ForegroundColor Cyan

# 清理历史 ClaudeSafe_* 规则
Get-NetFirewallRule -DisplayName "ClaudeSafe_*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule

if ($ClaudeExe -and (Test-Path -LiteralPath $ClaudeExe)) {
    # 1. 阻断一切 UDP（防 QUIC / WebRTC / DNS 绕过）
    New-NetFirewallRule -DisplayName "ClaudeSafe_Claude_CLI_Block_UDP" `
        -Group "ClaudeSafe" -Direction Outbound -Program $ClaudeExe -Protocol UDP -Action Block -Profile Any | Out-Null

    # 2. 阻断公网 TCP 直连（防代理崩掉后或走物理网卡直连）
    New-NetFirewallRule -DisplayName "ClaudeSafe_Claude_CLI_Block_Direct_Internet" `
        -Group "ClaudeSafe" -Direction Outbound -Program $ClaudeExe -Protocol TCP -RemoteAddress "Internet" -Action Block -Profile Any | Out-Null

    # 3. 阻断 Clash Fake-IP 网段 (198.18.0.0/15)，防止未开环境变量时通过 TUN 走 VPS 规则
    New-NetFirewallRule -DisplayName "ClaudeSafe_Claude_CLI_Block_FakeIP" `
        -Group "ClaudeSafe" -Direction Outbound -Program $ClaudeExe -Protocol TCP -RemoteAddress "198.18.0.0/15" -Action Block -Profile Any | Out-Null

    # 4. 阻断 Clash 其他日常端口 (7890/7891/7897/7898/7899)，仅留 7900 家宽端口
    New-NetFirewallRule -DisplayName "ClaudeSafe_Claude_CLI_Block_OtherClashPorts" `
        -Group "ClaudeSafe" -Direction Outbound -Program $ClaudeExe -Protocol TCP -RemoteAddress "127.0.0.1" -RemotePort @("7890", "7891", "7897", "7898", "7899") -Action Block -Profile Any | Out-Null

    # 5. 唯一代理放行白名单：127.0.0.1:7900
    New-NetFirewallRule -DisplayName "ClaudeSafe_Claude_CLI_Allow_Proxy_Only" `
        -Group "ClaudeSafe" -Direction Outbound -Program $ClaudeExe -Protocol TCP -RemoteAddress "127.0.0.1" -RemotePort "7900" -Action Allow -Profile Any | Out-Null

    Write-Host " [成功] 已锁定 Claude_CLI -> $ClaudeExe" -ForegroundColor Green
    Write-Host " [说明] 本机 Claude Code 为独立原生程序，未全局锁定 node.exe，以免影响 gemini/npm 等日常工具。" -ForegroundColor DarkGray
} else {
    Write-Host " [警告] 未检测到 claude.exe，跳过防火墙规则创建。" -ForegroundColor Yellow
}

# 创建桌面快捷方式（Claude Safe + 切换家宽出口）
$WshShell = New-Object -ComObject WScript.Shell
$Desktop = [System.Environment]::GetFolderPath('Desktop')

$Shortcut = $WshShell.CreateShortcut("$Desktop\Claude Safe.lnk")
$Shortcut.TargetPath = "$PSScriptRoot\claude-safe.bat"
$Shortcut.WorkingDirectory = $env:USERPROFILE
$Shortcut.Description = "安全启动 Claude CLI（带 IP 校验与家宽隔离沙盒 7900）"
$Shortcut.Save()

$ToggleShortcut = $WshShell.CreateShortcut("$Desktop\切换家宽出口.lnk")
$ToggleShortcut.TargetPath = "$PSScriptRoot\toggle-proxy.bat"
$ToggleShortcut.WorkingDirectory = "$PSScriptRoot"
$ToggleShortcut.IconLocation = "%SystemRoot%\System32\shell32.dll,14"
$ToggleShortcut.Description = "一键切换日常海外出口：🇺🇸 US-自建 VPS ↔ 🏠 家宽分流（国内始终直连）"
$ToggleShortcut.Save()

Write-Host "`n全部完成！已更新桌面快捷方式 'Claude Safe' 与 '切换家宽出口'。" -ForegroundColor Green
Get-NetFirewallRule -DisplayName "ClaudeSafe_*" | Format-Table DisplayName, Enabled, Direction, Action -AutoSize
pause
