param($req, $TriggerMetadata)

Push-OutputBinding -Name res -Value (
    [HttpResponseContext]@{
        StatusCode = 200
        Body = @{
            Message = "StructMatcher API online"
        }
    }
)
