param($req, $TriggerMetadata)

try {
    Import-Module StructMatcher -Force -ErrorAction Stop

    $module = Get-Module StructMatcher

    $body = @{
        Message = "StructMatcher API online"
        Loaded  = $true
        Module  = $module.Name
        Version = $module.Version.ToString()
    }
}
catch {
    $body = @{
        Message = $_.Exception.Message
        Loaded  = $false
    }
}

Push-OutputBinding -Name res -Value (
    [HttpResponseContext]@{
        StatusCode = 200
        Body       = $body
    }
)
