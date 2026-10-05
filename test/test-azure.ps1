# Load .env
Get-Content .env | ForEach-Object {

    if ($_ -match '^\s*#') { return }
    if ($_ -match '^\s*$') { return }

    if ($_ -match '^([^=]+)=(.*)$') {
        Set-Item `
            -Path "Env:$($Matches[1])" `
            -Value $Matches[2].Trim('"')
    }
}

$BaseUrl = $env:STRUCTMATCHER_FUNC_URL

if (-not $BaseUrl) {
    throw "STRUCTMATCHER_FUNC_URL not configured"
}

Get-ChildItem ./test/*_test.json | ForEach-Object {

    Write-Host ""
    Write-Host "Testing $($_.Name)" -ForegroundColor Cyan

    $Result = Invoke-RestMethod `
        -Uri $BaseUrl `
        -Method Post `
        -ContentType "application/json" `
        -InFile $_.FullName

    $Result | ConvertTo-Json -Depth 20
}
