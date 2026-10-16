$ErrorActionPreference = 'Stop'
$siteRoot = Join-Path $PSScriptRoot '..\_site'
$desktopShot = Join-Path $env:TEMP 'pcss-home.png'
$mobileShot = Join-Path $env:TEMP 'pcss-yearbooks-mobile.png'
$server = Start-Process -FilePath 'python' -ArgumentList @('-m', 'http.server', '4173', '--directory', $siteRoot) -WindowStyle Hidden -PassThru

try {
    $ready = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri 'http://127.0.0.1:4173/' -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -eq 200) { $ready = $true; break }
        } catch { Start-Sleep -Milliseconds 250 }
    }
    if (-not $ready) { throw 'Preview server did not become ready.' }

    npx.cmd -p '@playwright/test' playwright screenshot --viewport-size='1440,1000' --full-page 'http://127.0.0.1:4173/' $desktopShot
    if ($LASTEXITCODE -ne 0) { throw 'Desktop screenshot failed.' }
    npx.cmd -p '@playwright/test' playwright screenshot --viewport-size='390,844' --full-page 'http://127.0.0.1:4173/yearbooks.html' $mobileShot
    if ($LASTEXITCODE -ne 0) { throw 'Mobile screenshot failed.' }
    Write-Output $desktopShot
    Write-Output $mobileShot
} finally {
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}

