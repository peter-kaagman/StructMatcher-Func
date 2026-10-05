<#
.SYNOPSIS
    StructMatcher - Evaluate declarative rule sets against structured data.

.DESCRIPTION
    StructMatcher evaluates one or more rules against structured input data
    and returns the results of all matching rules.

    Supported data formats:
      - Hashtable
      - PSCustomObject
      - JSON text

    Supported rule formats:
      - Rule object
      - Rule collections
      - JSON object
      - JSON array

    Compatible with:
      - Windows PowerShell 5.1
      - PowerShell 7+

.NOTES
    Project : StructMatcher
    Version : 2.0.1
    Author  : Peter Kaagman
    License : MIT
    GitHub  : https://github.com/peter-kaagman/structmatcher

    Design goals:
      - Data-driven rule evaluation
      - No scriptblock execution
      - Predictable behavior
      - PowerShell 5.1 compatibility
#>
function Get-InfoFromStruct {
    <#
    Traverses a nested object structure (hashtables, PSCustomObjects, 
    and arrays) to retrieve the value at the specified path.
    Returns a custom object with properties:
    - Found: Indicates whether the path exists in the structure.
    - Value: The value at the specified path, or $null if not found.
    #>
param (
        [Parameter(Mandatory)]
        [string[]] $path,

        [Parameter(Mandatory)]
        $data
    )

    $current = $data

    foreach ($segment in $path) {
        if ($null -eq $current) {
            return [pscustomobject]@{
                Found = $false
                Value = $null
            }
        }
        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($segment)) {
                return [pscustomobject]@{
                    Found = $false
                    Value = $null
                }
            }
            $current = $current[$segment]
            continue
        }
        $property = $current.PSObject.Properties[$segment]
        if ($null -eq $property) {
            return [pscustomobject]@{
                Found = $false
                Value = $null
            }
        }
        $current = $property.Value
    }
    return [pscustomobject]@{
        Found = $true
        Value = $current
    }
}

function ConvertTo-NormalizedArray {
    <#
    Contains, NoContains, In, NotIn operators require the
    found value to be an array. This function normalizes
    the input to an array, handling strings and nested arrays
    appropriately.
    #>

    param($Value)

    if ($null -eq $Value) {
        return ,@()
    }

    if ($Value -is [string]) {
        try {
            $parsed = $null

            if (
                $Value.Trim().StartsWith("[") -and
                $Value.Trim().EndsWith("]")
            ) {
                $parsed = $Value | ConvertFrom-Json -ErrorAction Stop

                # PS7 returns a scalar for single-item JSON arrays.
                # Force the result back into an array.
                $Value = @($parsed)
            }
            else {
                $Value = $Value -split ','
            }
        }
        catch {
            $Value = $Value -split ','
        }
    }
    elseif ($Value -isnot [array]) {
        $Value = @($Value)
    }

    while (
        $Value.Count -eq 1 -and
        $Value[0] -is [array]
    ) {
        $Value = $Value[0]
    }

    return ,$Value
}

function ConvertTo-NormalizedStructure {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $InputObject
    )

    # JSON text
    if ($InputObject -is [string]) {

        if ([string]::IsNullOrWhiteSpace($InputObject)){
            throw "Input cannot be an empty string."
        }

        try {
            return $InputObject | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "Failed to parse JSON input: $($_.Exception.Message)"
        }
    }

    # Hashtable
    if ($InputObject -is [hashtable]) {
        return $InputObject
    }

    # PSCustomObject
    if ($InputObject -is [pscustomobject]) {
        return $InputObject
    }

    # Collection
    if ($InputObject -is [System.Collections.IEnumerable]) {
        return $InputObject
    }

    throw "Unsupported input type [$($InputObject.GetType().FullName)]. Supported types are Hashtable, PSCustomObject, collections and JSON text."
}

function Test-Condition{
param (
        [Parameter(Mandatory)] $Condition,
        [Parameter(Mandatory)] $Data
    )
    # ensure path exists
    if ( [string]::IsNullOrWhitespace($condition.path)) {
        throw "Condition is missing a 'path' property."
    }
    # ensure path is an array  
    $path = @($condition.path -split '\.')
    $check = $condition.check
    # If no operator is specified, default to Equals
    $operator = if ($condition.operator) { 
        $condition.operator 
    } else { 
        "Equals" 
    }
    # missingOk default to true if not specified
    $missingOk = if ($null -ne $condition.missingOk) {
        $condition.missingOk
    } else {
        $true
    }
    $result = Get-InfoFromStruct -path $path -data $data
    $value = $result.Value
    $isFound = $result.Found
    $conditionMet = 
    switch ($operator) {
        # Positive operators => node should exist and match the condition
        # missingOk is ignored for positive operators
        "Equals"         { ($isFound) -and ( $value -eq $check) }
        "Contains"       { ($isFound) -and ( (ConvertTo-NormalizedArray $value) -contains $check)}
        "In"             { ($isFound) -and ( $value -in (ConvertTo-NormalizedArray $check)) }
        "Like"           { ($isFound) -and ( $value -like $check) }
        "Match"          { ($isFound) -and ( $value -match $check) }
        "GreaterThan"    { ($isFound) -and ( $value -gt $check) }
        "LessThan"       { ($isFound) -and ( $value -lt $check) }
        "GreaterOrEqual" { ($isFound) -and ( $value -ge $check) }
        "LessOrEqual"    { ($isFound) -and ( $value -le $check) }

        # Negative operators => result depends on missingOk flag
        "NotEquals" {
            if ($missingOk) { 
                (-not $isFound) -or ($value -ne $check) }
            else { 
                $isFound -and ($value -ne $check) }
        }
        "NotContains" {
            if ($missingOk) { 
                (-not $isFound) -or ((ConvertTo-NormalizedArray $value) -notcontains $check) }
            else { 
                $isFound -and ((ConvertTo-NormalizedArray $value) -notcontains $check) }
        }
        "NotIn" {
            if ($missingOk) { 
                (-not $isFound) -or ($value -notin (ConvertTo-NormalizedArray $check)) }
            else { 
                $isFound -and ($value -notin (ConvertTo-NormalizedArray $check)) }
        }
        "NotLike" {
            if ($missingOk) { 
                (-not $isFound) -or ($value -notlike $check) }
            else { 
                $isFound -and ($value -notlike $check) }
        }
        "NotMatch" {
            if ($missingOk) { 
                (-not $isFound) -or ($value -notmatch $check) }
            else { 
                $isFound -and ($value -notmatch $check) }
        }
        default { 
            throw "Unsupported operator [$operator]. Supported operators are: Equals, NotEquals, Contains, NotContains, In, NotIn, Like, NotLike, Match, NotMatch, GreaterThan, LessThan, GreaterOrEqual, LessOrEqual."
        }
    }
    return $conditionMet
}

function Test-ConditionSet {
param (
        [Parameter(Mandatory)] $Rule,
        [Parameter(Mandatory)] $Data
    )

    # Ensure rule.result is not null
    if ($null -eq $rule.result) {
        throw "Rule.result can't be null. This is reserved to indicate that no conditions were met."
    }
    # Default to true, so that if no conditions are specified, the rule is considered met.
    $allMet = $true
    foreach ($condition in $rule.conditions) {
        $conditionMet = Test-Condition -Condition $condition -Data $data
        # Doing an AND so bail out if any condition fails
        if (-not $conditionMet) {
            $allMet = $false
            break
        }
    }
    if ($allMet) {
        return $rule.result
    }
    return $null
}

function Test-RulePropertyName {
param(
        [Parameter(Mandatory)] $Rules
    )

    $validRuleProperties = @( 'conditions', 'result', 'metadata')

    $validConditionProperties = @( 'path', 'operator', 'check', 'missingOk')
    foreach ($rule in @($rules)) {

        $rulePropertyNames =
        if ($rule -is [System.Collections.IDictionary]) {
            @($rule.Keys)
        } else {
            @($rule.PSObject.Properties.Name)
        }

        # Check if a ConditionSet has valid properties
        $unknownRuleProperties =
        $rulePropertyNames |
        Where-Object { $_ -notin $validRuleProperties }

        if ($unknownRuleProperties) {
            throw "Unknown rule properties: $($unknownRuleProperties -join ', ')"
        }

        foreach ($condition in @($rule.conditions)) {

            # Check if a Condition has valid properties
            $conditionPropertyNames =
            if ($condition -is [System.Collections.IDictionary]) {
                @($condition.Keys)
            } else {
                @($condition.PSObject.Properties.Name)
            }

            $unknownConditionProperties =
            $conditionPropertyNames |
            Where-Object { $_ -notin $validConditionProperties }

            if ($unknownConditionProperties) {
                throw "Unknown condition properties: $($unknownConditionProperties -join ', ')"
            }
        }
    }
}

function Invoke-StructMatcher {
param (
        [Parameter(Mandatory)] $rules,
        [Parameter(Mandatory)] $data
    )
    # Convert JSON input to a traverseable PowerShell structure.
    # Existing dictionaries, objects, and collections are retained.
    $rules = ConvertTo-NormalizedStructure $rules
    if ($null -eq $rules) {
        return @()
    }
    $data = ConvertTo-NormalizedStructure $data

    #Check if rule property names are valid
    Test-RulePropertyName -rules $rules

    # Keep matching results in insertion order while preventing duplicates.
    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($rule in $rules) {
        $reply = Test-ConditionSet -Rule $rule -Data $data
        if ($null -ne $reply -and -not $result.Contains($reply)) {
            [void]$result.Add($reply)
        }
    }
    return $result.ToArray()
}

# Public API
Export-ModuleMember -Function @(
    'Invoke-StructMatcher',
    'Test-ConditionSet',
    'Test-Condition'
)
