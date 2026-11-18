[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 1. 仅在当前沙盒会话注入专属家宽端口 7900（关闭窗口即销毁，不污染外部软件）
$env:HTTP_PROXY  = "http://127.0.0.1:7900"
$env:HTTPS_PROXY = "http://127.0.0.1:7900"
$env:ALL_PROXY   = "socks5h://127.0.0.1:7900"
$env:http_proxy  = "http://127.0.0.1:7900"
$env:https_proxy = "http://127.0.0.1:7900"
$env:all_proxy   = "socks5h://127.0.0.1:7900"
$env:NO_PROXY    = "localhost,127.0.0.1,::1"
$env:no_proxy    = "localhost,127.0.0.1,::1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Claude 专属家宽沙盒启动中 (7900)      " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 解析实际 claude.exe 二进制路径（跳过 PATH 中的包装脚本，兼容 npm 与 WinGet）
$ClaudeExe = $null
$candidates = @(
    "$env:USERPROFILE\npm-global\node_modules\@anthropic-ai\claude-code\bin\claude.exe",
    "$env:APPDATA\npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Anthropic.ClaudeCode_Microsoft.Winget.Source_8wekyb3d8bbwe\claude.exe"
)
Get-Command claude -All -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Source) {
        $cmdDir = Split-Path -Parent $_.Source
        $candidates += (Join-Path $cmdDir "node_modules\@anthropic-ai\claude-code\bin\claude.exe")
    }
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
if (-not $ClaudeExe) {
    Write-Host "`n[错误] 未找到 claude.exe，请检查 Claude Code CLI 安装路径。" -ForegroundColor Red
    pause
    exit 1
}

# 检查是否已部署 ClaudeSafe 防火墙硬锁
$fwRules = Get-NetFirewallRule -DisplayName "ClaudeSafe_Claude_CLI_*" -ErrorAction SilentlyContinue
if (-not $fwRules) {
    Write-Host "[提示] 尚未部署 ClaudeSafe 防火墙硬锁规则，请右键管理员运行 一键配置防火墙-管理员.bat" -ForegroundColor Yellow
}

# 读取当前 Clash 家宽策略组选中节点（强制 UTF-8 解码，避免 PowerShell 5.1 乱码）
try {
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $jsonText = $wc.DownloadString("http://127.0.0.1:9097/proxies/%F0%9F%8F%A0%20%E5%AE%B6%E5%AE%BD%E5%88%86%E6%B5%81")
    $homeGroup = $jsonText | ConvertFrom-Json
    if ($homeGroup.now) {
        Write-Host " 当前家宽节点: $($homeGroup.now)" -ForegroundColor DarkCyan
    }
} catch {}

# 2. 调用出口检测，强制通过 7900 验证家宽 IP
Write-Host "正在检测当前家宽出口 IP..." -ForegroundColor Yellow

try {
    $raw = curl.exe -s --connect-timeout 6 --max-time 10 --proxy socks5h://127.0.0.1:7900 https://ipinfo.io/json
    if (-not $raw) {
        throw "无法获取出口响应"
    }
    $resp = $raw | ConvertFrom-Json
    if (-not $resp.ip) {
        throw "无法获取有效的出口 IP"
    }

    Write-Host "----------------------------------------"
    Write-Host " 当前出口 IP : $($resp.ip)" -ForegroundColor Green
    Write-Host " 归属国家/地区: $($resp.country) ($($resp.city))" -ForegroundColor Green
    Write-Host " 节点运营商  : $($resp.org)" -ForegroundColor Green
    Write-Host "----------------------------------------"

    if ($resp.country -eq "CN") {
        Write-Host "`n[拦截] 当前处于中国大陆 IP 出口，存在封号风险，已中止启动！" -ForegroundColor Red
        pause
        exit 1
    }
}
catch {
    Write-Host "`n[熔断] 无法连接到家宽代理端口 127.0.0.1:7900！" -ForegroundColor Red
    Write-Host "请检查 Clash Verge 是否已启动并开启 7900 监听端口。" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "[安全] 家宽节点校验通过，启动 Claude Code CLI...`n" -ForegroundColor Green

# 3. 保留当前工作目录并拉起 Claude Code 原生可执行文件（支持管道与透传参数）
if ($MyInvocation.PipelineLength -gt 1) {
    $input | & $ClaudeExe @args
} else {
    & $ClaudeExe @args
}
exit $LASTEXITCODE
