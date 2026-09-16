param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDirectory '../..')
$templatePath = Join-Path $repoRoot 'local.settings.example.json'
$settingsPath = Join-Path $repoRoot 'local.settings.json'

if ((Test-Path $settingsPath) -and -not $Force) {
    Write-Host "$settingsPath already exists; leaving it unchanged." -ForegroundColor Yellow
    return
}

$outputs = azd env get-values --output json | ConvertFrom-Json
$requiredValues = @{
    sharepointConnectionRuntimeUrl = $outputs.sharepointConnectionRuntimeUrl
    sharepointSiteUrl = if ($outputs.sharepointSiteUrl) { $outputs.sharepointSiteUrl } else { $outputs.SHAREPOINT_SITE_URL }
    teamsConnectionRuntimeUrl = $outputs.teamsConnectionRuntimeUrl
    teamsTeamId = $outputs.TEAMS_TEAM_ID
    teamsChannelId = $outputs.TEAMS_CHANNEL_ID
    contentUnderstandingEndpoint = $outputs.contentUnderstandingEndpoint
}

$missingValues = $requiredValues.GetEnumerator() |
    Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Value) } |
    ForEach-Object Key

if ($missingValues) {
    throw "Required azd outputs are missing: $($missingValues -join ', '). Run 'azd provision' first."
}

$settings = Get-Content $templatePath -Raw | ConvertFrom-Json
$settings.Values.AZURE_CLIENT_ID = ''
$settings.Values.SHAREPOINTONLINE_CONNECTION_RUNTIME_URL = $requiredValues.sharepointConnectionRuntimeUrl
$settings.Values.SHAREPOINT_SITE_URL = $requiredValues.sharepointSiteUrl
$settings.Values.TEAMS_CONNECTION_RUNTIME_URL = $requiredValues.teamsConnectionRuntimeUrl
$settings.Values.TEAMS_TEAM_ID = $requiredValues.teamsTeamId
$settings.Values.TEAMS_CHANNEL_ID = $requiredValues.teamsChannelId
$settings.Values.CONTENT_UNDERSTANDING_ENDPOINT = $requiredValues.contentUnderstandingEndpoint

$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding utf8
Write-Host "Created $settingsPath from azd deployment outputs." -ForegroundColor Green
