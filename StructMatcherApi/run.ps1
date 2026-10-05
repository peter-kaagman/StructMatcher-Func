using namespace System.Net

param($req, $TriggerMetadata)

# Normalize incoming request data.
#
# Azure Functions may deserialize JSON into different PowerShell
# types depending on the runtime host. Convert supported input
# formats to a predictable structure so validation and dispatch
# logic do not need to handle runtime-specific variations.
function ConvertTo-NormalizedRequest {

    param([Parameter(Mandatory)]$InputObject)

    if ($InputObject -is [string]) {

        if ([string]::IsNullOrWhiteSpace($InputObject)) {
            throw "Request body cannot be empty."
        }

        $InputObject = $InputObject |
            ConvertFrom-Json -ErrorAction Stop
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        return [pscustomobject]$InputObject
    }

    return $InputObject
}

try {
    Import-Module StructMatcher -Force -ErrorAction Stop

    # Normalize the request payload
    $body = ConvertTo-NormalizedRequest $req.Body

    # Validate the input
    $propertyNames = @($body.PSObject.Properties.Name)
    $requiredProperties = @(
        'type',
        'input',
        'data'
    )
    foreach ($requiredProperty in @('type', 'input', 'data')) {
        if ($requiredProperty -notin $propertyNames) {
            throw "Request body is missing the required '$requiredProperty' property."
        }
    }

    if ([string]::IsNullOrWhiteSpace($body.type)) {
        throw "Property 'type' cannot be empty."
    }

    if ($null -eq $body.input) {
        throw "Property 'input' cannot be null."
    }

    if ($null -eq $body.data) {
        throw "Property 'data' cannot be null."
    }

    # Dispatch "input" and "data" using the check defined by "type" to StructMatcher
    $result = switch ($body.type.ToLowerInvariant()) {
        'ruleset' {
            @(
                Invoke-StructMatcher `
                    -Rules $body.input `
                    -Data $body.data `
                    -ErrorAction Stop
            )
        }

        'rule' {
            Test-ConditionSet `
                -Rule $body.input `
                -Data $body.data `
                -ErrorAction Stop
        }

        'condition' {
            Test-Condition `
                -Condition $body.input `
                -Data $body.data `
                -ErrorAction Stop
        }

        default {
            throw "Unsupported type [$($body.type)]. Supported types are: ruleset, rule and condition."
        }
    }

    # Prepare a responseBody
    $responseBody = @{
        success = $true
        type    = $body.type.ToLowerInvariant()
        result  = $result
    }

    $statusCode = [HttpStatusCode]::OK
}
catch {
    # Prepare the responseBody for an error
    $responseBody = @{
        success = $false
        error   = @{
            type    = $_.Exception.GetType().Name
            message = $_.Exception.Message
        }
    }

    $statusCode = [HttpStatusCode]::BadRequest
}


# Return the result (or error) to the client
Push-OutputBinding -Name res -Value (
    [HttpResponseContext]@{
        StatusCode = $statusCode
        Headers    = @{
            'Content-Type' = 'application/json'
        }
        Body       = $responseBody | ConvertTo-Json -Depth 100
    }
)
