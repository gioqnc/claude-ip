# 1. 仅在当前窗口注入专属家宽端口 7900（关闭窗口即销毁，不污染外部软件）
$env:HTTP_PROXY  = "http://127.0.0.1:7900"
$env:HTTPS_PROXY = "http://127.0.0.1:7900"
$env:ALL_PROXY   = "socks5h://127.0.0.1:7900"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Claude 专属家宽沙盒启动中 (7900)      " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 2. 调用出口检测，强制通过 7900 验证家宽 IP
Write-Host "正在检测当前家宽出口 IP..." -ForegroundColor Yellow

try {
    # 6 秒超时，通过本地 7900 端口请求节点信息
    $resp = curl.exe -s --connect-timeout 6 --proxy socks5h://127.0.0.1:7900 https://ipinfo.io/json | ConvertFrom-Json
    
    if (-not $resp.ip) {
        throw "无法获取有效的出口 IP"
    }

    Write-Host "----------------------------------------"
    Write-Host " 当前出口 IP : $($resp.ip)" -ForegroundColor Green
    Write-Host " 归属国家/地区: $($resp.country) ($($resp.city))" -ForegroundColor Green
    Write-Host " 节点运营商  : $($resp.org)" -ForegroundColor Green
    Write-Host "----------------------------------------"

    # 安全熔断：如果是 CN 节点，立即阻断
    if ($resp.country -eq "CN") {
        Write-Host "`n[拦截] 当前处于中国大陆 IP 出口，存在封号风险，已中止启动！" -ForegroundColor Red
        pause
        exit 1
    }
}
catch {
    Write-Host "`n[熔断] 无法连接到家宽代理端口 127.0.0.1:7900！" -ForegroundColor Red
    Write-Host "请检查 Clash Verge 是否已加载配置并启动监听。" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "[安全] 家宽节点校验通过，启动 Claude Code CLI...`n" -ForegroundColor Green

# 3. 正常拉起 Claude，并透传参数
& claude.exe $args
