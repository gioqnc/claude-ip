param(
    [switch]$StatusOnly,
    [switch]$NoWait,
    [string]$VpsNode = $env:CLAUDE_SAFE_VPS_NODE
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"
$ApiBase = "http://127.0.0.1:9097"
$GroupName = "节点选择"
$DefaultVpsNode = "🇺🇸 US-自建"
$HomeGroup = "🏠 家宽分流"
$EncodedGroup = [System.Uri]::EscapeDataString($GroupName)
$EncodedHome = [System.Uri]::EscapeDataString($HomeGroup)

# 自动读取 clash-verge.yaml 中的 secret（若无则为空）
$ApiSecret = ""
$clashYaml = Join-Path $env:APPDATA "io.github.clash-verge-rev.clash-verge-rev\clash-verge.yaml"
if (Test-Path -LiteralPath $clashYaml) {
    $secretLine = Select-String -Path $clashYaml -Pattern '^\s*secret:\s*(.+?)\s*$' | Select-Object -First 1
    if ($secretLine) {
        $secVal = $secretLine.Matches[0].Groups[1].Value.Trim("'", '"')
        if ($secVal -and $secVal -ne '""' -and $secVal -ne "''") {
            $ApiSecret = $secVal
        }
    }
}

function Invoke-ClashJson {
    param(
        [string]$Path,
        [string]$Method = "GET",
        [string]$JsonBody = $null
    )
    $req = [System.Net.HttpWebRequest]::Create("$ApiBase$Path")
    $req.Method = $Method
    $req.Timeout = 3000
    $req.ReadWriteTimeout = 3000
    if ($ApiSecret) {
        $req.Headers["Authorization"] = "Bearer $ApiSecret"
    }
    if (-not [string]::IsNullOrEmpty($JsonBody)) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($JsonBody)
        $req.ContentType = "application/json; charset=utf-8"
        $req.ContentLength = $bytes.Length
        $stream = $req.GetRequestStream()
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Close()
    }
    $resp = $req.GetResponse()
    try {
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $text = $reader.ReadToEnd()
        $reader.Close()
        if ($text) {
            return ($text | ConvertFrom-Json)
        }
        return $null
    } finally {
        $resp.Close()
    }
}

function Show-Balloon {
    param([string]$Title, [string]$Text, [string]$Icon = "Info")
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $ni = New-Object System.Windows.Forms.NotifyIcon
        $ni.Icon = [System.Drawing.SystemIcons]::Information
        $ni.BalloonTipIcon = $Icon
        $ni.BalloonTipTitle = $Title
        $ni.BalloonTipText = $Text
        $ni.Visible = $true
        $ni.ShowBalloonTip(3000)
        Start-Sleep -Milliseconds 2000
        $ni.Dispose()
    } catch {}
}

try {
    $cfg = Invoke-ClashJson -Path "/configs"
    $groupInfo = Invoke-ClashJson -Path "/proxies/$EncodedGroup"
    $homeInfo = Invoke-ClashJson -Path "/proxies/$EncodedHome"
} catch {
    Write-Host "[错误] 无法连接 Clash Verge 本地控制接口 ($ApiBase)。" -ForegroundColor Red
    Write-Host "请确认 Clash Verge 正在运行，且配置中有 external-controller: 127.0.0.1:9097。" -ForegroundColor Yellow
    Write-Host "详情: $($_.Exception.Message)" -ForegroundColor DarkGray
    if (-not $NoWait) { pause }
    exit 1
}

$currentNow = $groupInfo.now
$homeNode = $homeInfo.now
$allCandidates = @($groupInfo.all)

# 自动解析日常海外节点名：优先参数/环境变量，其次默认名，否则自动取【节点选择】中首个非家宽项
if (-not $VpsNode) {
    if ($allCandidates -contains $DefaultVpsNode) {
        $VpsNode = $DefaultVpsNode
    } else {
        $VpsNode = $allCandidates | Where-Object { $_ -ne $HomeGroup -and $_ -ne "DIRECT" -and $_ -ne "REJECT" } | Select-Object -First 1
    }
}
if (-not $VpsNode) {
    Write-Host "[错误] 未在 [$GroupName] 策略组中找到除 [$HomeGroup] 以外的日常海外节点。" -ForegroundColor Red
    if (-not $NoWait) { pause }
    exit 1
}

if ($StatusOnly) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Clash 当前运行模式 : $($cfg.mode)"
    Write-Host " 日常出口 [$GroupName]: $currentNow"
    Write-Host " 沙盒端口 7900 [$HomeGroup]: $homeNode"
    Write-Host "========================================" -ForegroundColor Cyan
    exit 0
}

# 确保处于 rule 模式，保证微信/B站等国内流量继续直连不烧家宽流量
if ($cfg.mode -ne "rule") {
    Invoke-ClashJson -Path "/configs" -Method "PATCH" -JsonBody '{"mode":"rule"}' | Out-Null
}

if ($currentNow -eq $HomeGroup) {
    $target = $VpsNode
    $title = "已切回：日常 VPS 模式"
    $summary = "海外流量 -> $VpsNode | 国内直连 | 仅沙盒/指纹浏览器7900走家宽"
    $fg = "Green"
} else {
    $target = $HomeGroup
    $title = "已切换：临时家宽模式"
    $summary = "海外网页全部 -> $HomeGroup ($homeNode) | 国内流量仍直连"
    $fg = "Yellow"
}

$bodyJson = (@{ name = $target } | ConvertTo-Json -Compress)
Invoke-ClashJson -Path "/proxies/$EncodedGroup" -Method "PUT" -JsonBody $bodyJson | Out-Null

# 仅关闭经由“节点选择”的旧连接，让浏览器立即切换出口；不影响 7900 沙盒/Telegram/国内直连
$closed = 0
try {
    $conns = Invoke-ClashJson -Path "/connections"
    if ($conns -and $conns.connections) {
        foreach ($c in $conns.connections) {
            if ($c.chains -and ($c.chains -contains $GroupName)) {
                try {
                    Invoke-ClashJson -Path "/connections/$($c.id)" -Method "DELETE" | Out-Null
                    $closed++
                } catch {}
            }
        }
    }
} catch {}

Write-Host "==================================================" -ForegroundColor $fg
Write-Host "  $title" -ForegroundColor $fg
Write-Host "  $summary" -ForegroundColor White
Write-Host "  已刷新旧连接数: $closed（7900 沙盒与国内直连不受影响）" -ForegroundColor DarkGray
Write-Host "==================================================" -ForegroundColor $fg

Show-Balloon -Title $title -Text $summary
if (-not $NoWait) {
    Start-Sleep -Milliseconds 2000
}
