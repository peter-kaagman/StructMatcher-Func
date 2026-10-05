@{
	# Module metadata
	ModuleVersion = '2.0.1'
	GUID = 'd0cdddc2-5ef9-4c89-bdc5-b4048414ac74'
	Author = 'Peter Kaagman'
	CompanyName = 'Atlas College'
	Copyright = '(c) 2026 Peter Kaagman. Licensed under MIT License.'
	Description = 'Evaluate declarative rule sets against nested structured data and return matching results. Supports JSON, hashtables, PSCustomObjects, and iterable rule collections.'

	# Module components
	RootModule = 'StructMatcher.psm1'
	PowerShellVersion = '5.1'

	# Functions to export
	FunctionsToExport = @(
		'Invoke-StructMatcher',
		'Test-ConditionSet',
		'Test-Condition'
	)
	# Cmdlets to export
	CmdletsToExport = @()

	# Variables to export
	VariablesToExport = @()

	# Aliases to export
	AliasesToExport = @()

	# Private data
	PrivateData = @{
		PSData = @{
			Tags = @(
				'PowerShell', 
				'StructMatcher', 
				'RuleEngine', 
				'Conditions', 
				'Rules', 
				'JSON', 
				'Hashtable', 
				'PSCustomObject'
			)
			ReleaseNotes = @'
Exports Invoke-StructMatcher for evaluating conditions against nested structures.

2.0.1
- Refactored internal rule evaluation.
- Public API reduced to Invoke-StructMatcher.
- Added support for Hashtables, PSCustomObjects, and JSON text as input.

1.0.1
- Initial release
- Outer loop for rule evaluation not within the function, but rather in the calling context.
- Input data is expected to be a hashtable or PSCustomObject.
'@
			ProjectUri = 'https://github.com/peter-kaagman/StructMatcher'
			LicenseUri = 'https://github.com/peter-kaagman/StructMatcher/blob/main/LICENSE'
		}
	}
}
