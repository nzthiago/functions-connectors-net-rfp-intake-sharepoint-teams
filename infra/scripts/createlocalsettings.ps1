$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDirectory '../..')
$templatePath = Join-Path $repoRoot 'local.settings.example.json'
$settingsPath = Join-Path $repoRoot 'local.settings.json'

$outputs = azd env get-values --output json | ConvertFrom-Json
$requiredValues = @{
    sharepointConnectionRuntimeUrl = $outputs.sharepointConnectionRuntimeUrl
    sharepointSiteUrl = if ($outputs.sharepointSiteUrl) { $outputs.sharepointSiteUrl } else { $outputs.SHAREPOINT_SITE_URL }
    teamsConnectionRuntimeUrl = $outputs.teamsConnectionRuntimeUrl
    teamsTeamId = $outputs.TEAMS_TEAM_ID
    teamsChannelId = $outputs.TEAMS_CHANNEL_ID
    documentIntelligenceEndpoint = $outputs.documentIntelligenceEndpoint
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
$settings.Values.DOCUMENT_INTELLIGENCE_ENDPOINT = $requiredValues.documentIntelligenceEndpoint

$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding utf8
Write-Host "Populated $settingsPath from azd deployment outputs." -ForegroundColor Green
