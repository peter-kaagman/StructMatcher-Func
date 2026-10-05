# This scipts assumes "func" is actively running
$BaseUrl = "http://localhost:7071/api/StructMatcherApi"

Get-ChildItem ./test/*.json | ForEach-Object {

    Write-Host ""
    Write-Host "Testing $($_.Name)" -ForegroundColor Cyan

    $Result = Invoke-RestMethod `
        -Uri $BaseUrl `
        -Method Post `
        -ContentType "application/json" `
        -InFile $_.FullName

    $Result | ConvertTo-Json -Depth 20
}
