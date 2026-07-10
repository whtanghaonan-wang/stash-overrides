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

function Test-UrlBlocked {
    param([string]$Url)

    $uri = [uri]$Url
    if ($rejectDomains.Contains($uri.Host)) {
        return $true
    }

    return [bool]($rewriteRules | Where-Object { $_.IsMatch($Url) } | Select-Object -First 1)
}

$cases = @(
    @{ Url = 'http://nbcollectretry.kugou.com/v3/post'; Expected = $true; Label = 'retry collector' }
    @{ Url = 'http://rt-m.kugou.com/v2/post'; Expected = $true; Label = 'real-time ad report' }
    @{ Url = 'http://mdpfilebssdlbig.kugou.com/472d0beed70f72b81c05f05dba21df3d.png'; Expected = $true; Label = 'startup image asset' }
    @{ Url = 'http://acshow2.kugou.com/mfx-shortvideo/conf/kv/app'; Expected = $true; Label = 'promotion config' }
    @{ Url = 'https://gateway.kugou.com/v4/mobile_splash'; Expected = $true; Label = 'mobile splash config' }
    @{ Url = 'http://mcloudservice.kugou.com/v1/get_version'; Expected = $false; Label = 'app version check' }
    @{ Url = 'http://tools.mobile.kugou.com/v1/privacy/info'; Expected = $false; Label = 'privacy configuration' }
    @{ Url = 'https://gateway.kugou.com/v1/user/profile'; Expected = $false; Label = 'normal gateway request' }
)

$failures = @()
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
