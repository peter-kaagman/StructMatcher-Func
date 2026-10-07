# StructMatcher-Func 

PowerShell Azure Function that exposes the public StructMatcher API through an HTTP endpoint.

StructMatcher-Func acts as a thin HTTP wrapper around StructMatcher. It normalizes and validates incoming requests, dispatches them to the requested StructMatcher entry point, and returns the result as JSON. The Function contains no rule-evaluation logic itself; that responsibility remains entirely within the separate StructMatcher module.

The StructMatcher source code and module documentation are available in the [StructMatcher repository](https://github.com/peter-kaagman/StructMatcher). For the background, motivation and design considerations behind StructMatcher, see [Mysite](https://mysite.prjv.nl/article/from_distribution_lists_to_a_rule_evaluation_engine).


## API

### Endpoint

```text
POST /api/StructMatcherApi
```

The request body must contain three properties:

```json
{
  "type": "condition | rule | ruleset",
  "input": {},
  "data": {}
}
```

| Property | Description |
|---|---|
| `type` | Selects the StructMatcher entry point |
| `input` | Condition, rule, or ruleset to evaluate |
| `data` | Structured test data |

### Entry points

| Type | StructMatcher function | Result |
|---|---|---|
| `condition` | `Test-Condition` | Boolean |
| `rule` | `Test-ConditionSet` | Rule result or `null` |
| `ruleset` | `Invoke-StructMatcher` | Array of matching results |

## Examples

### Condition

Request:

```json
{
  "type": "condition",
  "input": {
    "path": "department",
    "operator": "NotEquals",
    "check": "IT"
  },
  "data": {
    "department": "Finance"
  }
}
```

Response:

```json
{
  "success": true,
  "type": "condition",
  "result": true
}
```

### Rule

Request:

```json
{
  "type": "rule",
  "input": {
    "result": "Blaat",
    "conditions": [
      {
        "path": "department",
        "operator": "Equals",
        "check": "IT"
      },
      {
        "path": "location",
        "operator": "Equals",
        "check": "Hoorn"
      }
    ]
  },
  "data": {
    "department": "IT",
    "location": "Hoorn"
  }
}
```

Response:

```json
{
  "success": true,
  "type": "rule",
  "result": "Blaat"
}
```

### RuleSet

Request:

```json
{
  "type": "ruleset",
  "input": [
    {
      "result": "IT Hoorn",
      "conditions": [
        {
          "path": "department",
          "operator": "Equals",
          "check": "IT"
        },
        {
          "path": "location",
          "operator": "Equals",
          "check": "Hoorn"
        }
      ]
    },
    {
      "result": "IT",
      "conditions": [
        {
          "path": "department",
          "operator": "Equals",
          "check": "IT"
        }
      ]
    }
  ],
  "data": {
    "department": "IT",
    "location": "Hoorn"
  }
}
```

Response:

```json
{
  "success": true,
  "type": "ruleset",
  "result": [
    "IT Hoorn",
    "IT"
  ]
}
```

## Project structure

```text
StructMatcher-Func/
├── Modules/
│   └── StructMatcher/
├── StructMatcherApi/
│   ├── function.json
│   └── run.ps1
├── test/
│   ├── condition_test.json
│   ├── rule_test.json
│   ├── ruleset_test.json
│   ├── test-local.ps1
│   └── test-azure.ps1
├── .env.example
├── host.json
├── local.settings.json
├── profile.ps1
└── requirements.psd1
```

> [!IMPORTANT]
> The `Modules/StructMatcher` directory is used only for local development and debugging.
>
> StructMatcher is maintained in its own repository and remains the source of truth. Do not develop or modify StructMatcher inside the StructMatcher-Func repository.
>
> When a StructMatcher change is required:
>
> 1. Make the change in the StructMatcher repository.
> 2. Run the StructMatcher Pester tests.
> 3. Commit and push the change there.
> 4. Refresh the local copy under `Modules/StructMatcher`.
>
> The Azure deployment pipeline retrieves StructMatcher from its own repository when building the deployment artifact. The local module copy is not the production source.


## Local development

### Requirements

- PowerShell 7
- .NET SDK
- Azure Functions Core Tools v4
- A local copy of StructMatcher under `Modules/StructMatcher`

Verify the tools:

```bash
pwsh --version
dotnet --version
func --version
```

### Local settings

Create `local.settings.json`:

```json
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "powershell"
  }
}
```

Do not commit environment-specific settings or secrets.

### Start the Function host

From the repository root:

```bash
func start
```

The local endpoint is:

```text
http://localhost:7071/api/StructMatcherApi
```

## Testing

The test payloads are shared by the local and Azure test scripts. This ensures that both environments are tested against the same API contract.

### Local integration test

Start the local Function host:

```bash
func start
```

In a second terminal:

```powershell
./test/test-local.ps1
```

This tests:

```text
HTTP request
→ local Azure Functions host
→ run.ps1
→ local StructMatcher module
→ JSON response
```

### Azure integration test

Create a local `.env` file:

```dotenv
STRUCTMATCHER_FUNC_URL="GetThisFromYourAzureEnvironment"
```

The actual value contains the Azure Function endpoint and a function-specific key:

```text
https://<function-app>.azurewebsites.net/api/StructMatcherApi?code=<function-key>
```

Run:

```powershell
./test/test-azure.ps1
```

This tests:

```text
HTTP request
→ deployed Azure Function
→ deployed StructMatcher module
→ JSON response
```

### Expected test output

```text
Testing condition_test.json
{
  "success": true,
  "result": true,
  "type": "condition"
}

Testing rule_test.json
{
  "success": true,
  "result": "Blaat",
  "type": "rule"
}

Testing ruleset_test.json
{
  "success": true,
  "result": [
    "IT Hoorn",
    "IT"
  ],
  "type": "ruleset"
}
```

## Environment configuration

The real `.env` file must not be committed.

Add this to `.gitignore`:

```gitignore
.env
local.settings.json
```

Commit an `.env.example` instead:

```dotenv
STRUCTMATCHER_FUNC_URL="GetThisFromYourAzureEnvironment"
```

## Function keys

Use separate Azure Function keys for separate consumers, such as:

```text
test
rulebuilder
manual
```

This allows a key to be revoked or rotated without affecting other consumers.

The function hostname remains the same. The value supplied through the `code` query parameter identifies the key used by the client.

## Error response

Invalid requests return a structured error response:

```json
{
  "success": false,
  "error": {
    "type": "RuntimeException",
    "message": "Request body is missing the required 'type' property."
  }
}
```

No-match results are not errors:

- A condition returns `false`.
- A rule returns `null`.
- A ruleset returns an empty array.

## Responsibilities

StructMatcher-Func is responsible for:

- Accepting HTTP requests
- Normalizing the request body
- Validating the API envelope
- Dispatching to the selected StructMatcher function
- Serializing the result as JSON

StructMatcher is responsible for:

- Input normalization of rules and test data
- Rule validation
- Condition evaluation
- Rule evaluation
- Ruleset evaluation
- Result semantics

StructMatcher-Func must not duplicate StructMatcher business logic.

## CI/CD

StructMatcher-Func is deployed automatically using GitHub Actions.

Deployments are release-driven and triggered by Git tags:

```bash
git tag -a v0.1.0 -m "Release message"
git push origin v0.1.0
```

The build pipeline:

1. Checks out the StructMatcher-Func repository.
2. Checks out the latest StructMatcher module from the StructMatcher repository.
3. Creates a deployment package.
4. Authenticates to Azure using OpenID Connect (OIDC).
5. Deploys the package to the Azure Function App.

GitHub Actions authenticates against Azure using a GitHub Environment named:

```text
production
```

The Azure Entra App Registration trusts this environment through a federated identity credential.

No client secrets or publish profiles are used.

The deployment workflow is defined in:

```text
.github/workflows/build.yml
```
