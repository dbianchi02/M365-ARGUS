#Requires -Version 7.2
Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Module constants
# ---------------------------------------------------------------------------
$script:ArgusModuleRoot = $PSScriptRoot

$script:ArgusVersion = & {
    $manifest = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'ARGUS.psd1')
    $prerelease = $manifest.PrivateData.PSData.Prerelease
    if ($prerelease) { "$($manifest.ModuleVersion)-$prerelease" } else { "$($manifest.ModuleVersion)" }
}

$script:ArgusSchemaVersion = '1.0'

# Area name -> Id prefix and display name, in report order.
$script:ArgusAreas = [ordered]@{
    EntraID      = @{ Code = 'ENT'; DisplayName = 'Entra ID' }
    Applications = @{ Code = 'APP'; DisplayName = 'Applications' }
    Licensing    = @{ Code = 'LIC'; DisplayName = 'Licensing' }
    GroupsTeams  = @{ Code = 'GRP'; DisplayName = 'Groups & Teams' }
    SharePoint   = @{ Code = 'SPO'; DisplayName = 'SharePoint & OneDrive' }
    Exchange     = @{ Code = 'EXO'; DisplayName = 'Exchange Online' }
}

$script:ArgusSeverities = @('Critical', 'High', 'Medium', 'Low', 'Info')
$script:ArgusStatuses = @('Passed', 'Failed', 'Investigate', 'Skipped', 'Error', 'NotRun')

$script:ArgusServices = [ordered]@{
    Graph      = 'Microsoft Graph'
    Exchange   = 'Exchange Online'
    SharePoint = 'SharePoint Online (PnP.PowerShell)'
}

# Licence (service plan) friendly names and implications (P2 includes P1).
$script:ArgusLicenses = @{
    AAD_PREMIUM    = @{ DisplayName = 'Entra ID P1'; ImpliedBy = @('AAD_PREMIUM_P2') }
    AAD_PREMIUM_P2 = @{ DisplayName = 'Entra ID P2'; ImpliedBy = @() }
}

# Global exclusion list -> finding columns it is matched against (case-insensitive).
$script:ArgusExclusionColumns = [ordered]@{
    UserPrincipalNames = @('UserPrincipalName', 'UPN')
    ObjectIds          = @('ObjectId', 'Id', 'UserId')
    GroupIds           = @('GroupId')
    SiteUrls           = @('SiteUrl')
    AppIds             = @('AppId')
}

# ---------------------------------------------------------------------------
# Per-session state
# ---------------------------------------------------------------------------
$script:ArgusRegistrationTarget = $null   # List used by Register-ArgusCheck during Import-ArgusCheck
$script:ArgusConnection = $null           # set by Connect-Argus (Phase 4)
$script:ArgusDataCache = @{}              # per-run data set cache (Get-ArgusData)
$script:ArgusDataSetLoaders = @{}         # data set name -> scriptblock (Phase 4)

# ---------------------------------------------------------------------------
# Load functions
# ---------------------------------------------------------------------------
foreach ($folder in 'Private', 'Public') {
    $path = Join-Path -Path $PSScriptRoot -ChildPath $folder
    if (-not (Test-Path -LiteralPath $path)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $path -Filter '*.ps1' -File | Sort-Object Name) {
        try {
            . $file.FullName
        }
        catch {
            throw "ARGUS: failed to load '$($file.FullName)': $_"
        }
    }
}

# ---------------------------------------------------------------------------
# Register built-in checks
# ---------------------------------------------------------------------------
$script:ArgusBuiltInChecks = @(Import-ArgusCheck -Path (Join-Path $PSScriptRoot 'Checks') -ErrorAction Continue)

Update-TypeData -TypeName 'Argus.CheckInfo' -DefaultDisplayPropertySet 'Id', 'Area', 'Severity', 'Title' -Force

# Exports are controlled by FunctionsToExport in ARGUS.psd1 (explicit list).
# Export-ModuleMember is intentionally not used here: PSScriptAnalyzer 1.25 crashes
# (ProvideCommentHelp/GetExportedFunction) on Export-ModuleMember with a variable argument.
