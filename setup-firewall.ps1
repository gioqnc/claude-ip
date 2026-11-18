# 需要以管理员权限运行（用于一键部署 Windows 内核级防火墙规则）
# 规则效果：
# 1. 彻底切断 claude.exe 和 node.exe 的一切公网直连（防代理崩溃回落至直连）
# 2. 彻底阻断 UDP 流量（防 WebRTC STUN 探测与本地 DNS 泄露）
# 3. 唯一放行白名单：仅允许向 127.0.0.1:7900（专属家宽代理端口）发起 TCP 连接

$ClaudeExe = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $ClaudeExe) { 
    $ClaudeExe = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Anthropic.ClaudeCode_Microsoft.Winget.Source_8wekyb3d8bbwe\claude.exe" 
}
$NodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $NodeExe) { 
    $NodeExe = "C:\Program Files\nodejs\node.exe" 
}

$Targets = @(
    @{ Name = "Claude_CLI";  Path = $ClaudeExe },
    @{ Name = "Claude_Node"; Path = $NodeExe }
)

Write-Host "正在部署 Windows 防火墙沙盒拦截规则..." -ForegroundColor Cyan

# 清理历史规则
Remove-NetFirewallRule -DisplayName "ClaudeSafe_*" -ErrorAction SilentlyContinue

foreach ($item in $Targets) {
    if (Test-Path $item.Path) {
        # 阻断一切 UDP（防 WebRTC / DNS 绕过）
        New-NetFirewallRule -DisplayName "ClaudeSafe_$($item.Name)_Block_UDP" `
            -Direction Outbound -Program $item.Path -Protocol UDP -Action Block -Profile Any | Out-Null
        
        # 阻断公网 TCP 直连（防代理崩掉后自动回落到真实物理网卡）
        New-NetFirewallRule -DisplayName "ClaudeSafe_$($item.Name)_Block_Direct_Internet" `
            -Direction Outbound -Program $item.Path -Protocol TCP -RemoteAddress "Internet" -Action Block -Profile Any | Out-Null
        
        # 唯一白名单：只放行去往本地 7900 家宽端口
        New-NetFirewallRule -DisplayName "ClaudeSafe_$($item.Name)_Allow_Proxy_Only" `
            -Direction Outbound -Program $item.Path -Protocol TCP -RemoteAddress 127.0.0.1 -RemotePort 7900 -Action Allow -Profile Any | Out-Null

        Write-Host " [成功] 已锁定: $($item.Name) -> $($item.Path)" -ForegroundColor Green
    } else {
        Write-Host " [跳过] 未检测到程序: $($item.Path)" -ForegroundColor Yellow
    }
}

# 创建桌面快捷方式
$WshShell = New-Object -ComObject WScript.Shell
$Desktop = [System.Environment]::GetFolderPath('Desktop')
$Shortcut = $WshShell.CreateShortcut("$Desktop\Claude Safe.lnk")
$Shortcut.TargetPath = "$PSScriptRoot\claude-safe.bat"
$Shortcut.WorkingDirectory = "$PSScriptRoot"
$Shortcut.Description = "安全启动 Claude CLI（带 IP 校验与家宽隔离沙盒）"
$Shortcut.Save()

Write-Host "`n全部完成！已在桌面生成 'Claude Safe' 启动入口。" -ForegroundColor Green
pause
