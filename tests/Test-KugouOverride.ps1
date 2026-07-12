param(
    [string]$OverridePath = (Join-Path $PSScriptRoot '..\kugou-adblock.stoverride')
)

$content = Get-Content -Raw -LiteralPath $OverridePath

$rejectDomains = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($match in [regex]::Matches($content, '(?m)^\s*-\s+DOMAIN,([^,]+),REJECT(?:,.*)?$')) {
    [void]$rejectDomains.Add($match.Groups[1].Value.Trim())
}

$rewriteRules = foreach ($line in $content -split "`r?`n") {
    if ($line -match '^\s*-\s+(\^.+?)\s+-\s+reject(?:-dict)?\s*$') {
        [regex]::new($Matches[1])
    }
}

$scriptRules = foreach ($line in $content -split "`r?`n") {
    if ($line -match '^\s*-\s+match:\s+(\^.+?)\s*$') {
        [regex]::new($Matches[1])
    }
}

function Test-UrlBlocked {
    param([string]$Url)

    $uri = [uri]$Url
    if ($rejectDomains.Contains($uri.Host)) {
        return $true
    }

    if ($rewriteRules | Where-Object { $_.IsMatch($Url) } | Select-Object -First 1) {
        return $true
    }

    return [bool]($scriptRules | Where-Object { $_.IsMatch($Url) } | Select-Object -First 1)
}

$cases = @(
    @{ Url = 'http://nbcollectretry.kugou.com/v3/post'; Expected = $true; Label = 'retry collector' }
    @{ Url = 'http://rt-m.kugou.com/v2/post'; Expected = $true; Label = 'real-time ad report' }
    @{ Url = 'http://mdpfilebssdlbig.kugou.com/472d0beed70f72b81c05f05dba21df3d.png'; Expected = $true; Label = 'startup image asset' }
    @{ Url = 'http://acshow2.kugou.com/mfx-shortvideo/conf/kv/app'; Expected = $true; Label = 'promotion config' }
    @{ Url = 'http://bjacshow2.kugou.com/mfx-appconf/cdn/start/config.json'; Expected = $true; Label = 'Fanxing startup config' }
    @{ Url = 'http://acshow2.kugou.com/mfx-kugoulive/room/list'; Expected = $true; Label = 'promoted live room list' }
    @{ Url = 'http://acshow2.kugou.com/show7/json/v2/cdn/getscfg'; Expected = $true; Label = 'Fanxing scene config' }
    @{ Url = 'http://service3.fanxing.kugou.com/video/mo/gateway/api/config'; Expected = $true; Label = 'direct-IP live gateway config' }
    @{ Url = 'https://gateway.kugou.com/v4/mobile_splash'; Expected = $true; Label = 'mobile splash config' }
    @{ Url = 'http://adserviceretry.kglink.cn/v4/mobile_splash_sort'; Expected = $true; Label = 'retry splash config' }
    @{ Url = 'http://mcloudservice.kugou.com/v1/get_version'; Expected = $false; Label = 'app version check' }
    @{ Url = 'http://tools.mobile.kugou.com/v1/privacy/info'; Expected = $false; Label = 'privacy configuration' }
    @{ Url = 'http://service3.fanxing.kugou.com/video/mo/live/pull/mutiline/cfg'; Expected = $false; Label = 'live playback quality config' }
    @{ Url = 'https://gateway.kugou.com/v1/user/profile'; Expected = $false; Label = 'normal gateway request' }
)

$failures = @()
foreach ($domain in @(
    'adservice.kugou.com',
    'adserviceretry.kugou.com',
    'adserviceretry.kglink.cn',
    'acshow.kugou.com',
    'bjacshow.kugou.com',
    'service1.fanxing.kugou.com'
)) {
    if ($rejectDomains.Contains($domain)) {
        $failures += "[$domain] splash config must be sanitized instead of hard-rejected"
    }
}

foreach ($case in $cases) {
    $actual = Test-UrlBlocked -Url $case.Url
    if ($actual -ne $case.Expected) {
        $failures += "[$($case.Label)] expected blocked=$($case.Expected), got $actual ($($case.Url))"
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Kugou override checks passed: $($cases.Count) cases"
