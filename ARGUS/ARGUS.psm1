#Requires -Version 7.2
Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Module constants
# ---------------------------------------------------------------------------
$script:ArgusModuleRoot = $PSScriptRoot

$script:ArgusManifest = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'ARGUS.psd1')

$script:ArgusVersion = & {
    $prerelease = $script:ArgusManifest.PrivateData.PSData.Prerelease
    if ($prerelease) { "$($script:ArgusManifest.ModuleVersion)-$prerelease" } else { "$($script:ArgusManifest.ModuleVersion)" }
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
    Copilot      = @{ Code = 'COP'; DisplayName = 'Copilot & Agents' }
}

$script:ArgusSeverities = @('Critical', 'High', 'Medium', 'Low', 'Info')
$script:ArgusStatuses = @('Passed', 'Failed', 'Investigate', 'Skipped', 'Error', 'NotRun')

$script:ArgusServices = [ordered]@{
    Graph      = 'Microsoft Graph'
    Exchange   = 'Exchange Online'
    SharePoint = 'SharePoint Online (PnP.PowerShell)'
    Commerce   = 'Microsoft 365 commerce policies (MSCommerce)'
}

# Licence (service plan) friendly names and implications (P2 includes P1).
$script:ArgusLicenses = @{
    AAD_PREMIUM    = @{ DisplayName = 'Entra ID P1'; ImpliedBy = @('AAD_PREMIUM_P2') }
    AAD_PREMIUM_P2 = @{ DisplayName = 'Entra ID P2'; ImpliedBy = @() }
    # Copilot and Agent 365 service plans ("Product names and service plan identifiers for licensing", 2026-10-19).
    M365_COPILOT_APPS = @{ DisplayName = 'Microsoft 365 Copilot'; ImpliedBy = @() }
    AGENT_365         = @{ DisplayName = 'Agent 365'; ImpliedBy = @() }
}

# Free, viral and developer SKUs (skuPartNumber) that are not paid seats: default IgnoredSkus of the Licensing
# checks. Part numbers from "Product names and service plan identifiers for licensing" (Microsoft Learn, 2026-10-19).
# Trial subscriptions are detected separately from /directory/subscriptions (isTrial).
$script:ArgusFreeSkus = @(
    'FLOW_FREE', 'POWER_BI_STANDARD', 'POWER_BI_STANDARD_FACULTY', 'POWER_BI_STANDARD_STUDENT', 'POWER_BI_INDIVIDUAL_USER'
    'TEAMS_EXPLORATORY', 'Microsoft_Teams_Exploratory_Dept', 'TEAMS_FREE', 'TEAMS_COMMERCIAL_TRIAL', 'MS_TEAMS_IW'
    'POWERAPPS_VIRAL', 'POWERAPPS_DEV', 'POWERAPPS_INDIVIDUAL_USER', 'CCIBOTS_PRIVPREV_VIRAL', 'Power_Pages_vTrial_for_Makers'
    'DYN365_CUSTOMER_INSIGHTS_VIRAL', 'Dynamics_365_Customer_Service_Enterprise_viral_trial', 'Dynamics_365_Field_Service_Enterprise_viral_trial'
    'Dynamics_365_Sales_Premium_Viral_Trial', 'Dynamics_365_Guides_vTrial', 'Microsoft_Cloud_for_Sustainability_vTrial', 'FORMS_PRO'
    'WINDOWS_STORE', 'RIGHTSMANAGEMENT_ADHOC', 'STREAM', 'MCOPSTNC', 'MICROSOFT_BUSINESS_CENTER', 'SMB_APPS', 'DEVELOPERPACK', 'DEVELOPERPACK_E5'
)

# Microsoft Graph endpoint (global cloud).
$script:ArgusGraphBaseUri = 'https://graph.microsoft.com'

# Read-only Graph permissions ARGUS always needs, whatever checks are selected:
# tenant name/domains, licence detection (Entra ID P1/P2), concealed report names,
# and the signed-in user's own role assignments (Test-ArgusPrerequisite).
$script:ArgusCorePermissions = @('Organization.Read.All', 'LicenseAssignment.Read.All', 'ReportSettings.Read.All', 'RoleManagement.Read.Directory')

# Roles recommended for the account running ARGUS with delegated (interactive) sign-in.
$script:ArgusRecommendedRoles = @('Global Reader', 'Reports Reader')

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
$script:ArgusConnection = $null           # set by Connect-Argus
$script:ArgusDataCache = @{}              # per-run data set cache (Get-ArgusData)
$script:ArgusDataSetLoaders = @{}         # data set name -> scriptblock (registered below)
$script:ArgusDataSetNotes = @{}           # data set name -> notes recorded while loading (e.g. signInActivity omitted)
$script:ArgusCommercePolicies = $null     # MSCommerce product policies read at Connect-Argus (cleared by Disconnect-Argus)

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
# Register data set loaders
# ---------------------------------------------------------------------------
foreach ($dataSet in Get-ArgusDataSetDefinition) {
    $script:ArgusDataSetLoaders[$dataSet.Name] = $dataSet.Loader
}

# ---------------------------------------------------------------------------
# Register built-in checks
# ---------------------------------------------------------------------------
$script:ArgusBuiltInChecks = @(Import-ArgusCheck -Path (Join-Path $PSScriptRoot 'Checks') -ErrorAction Continue)

Update-TypeData -TypeName 'Argus.CheckInfo' -DefaultDisplayPropertySet 'Id', 'Area', 'Severity', 'Title' -Force

# Exports are controlled by FunctionsToExport in ARGUS.psd1 (explicit list).
# Export-ModuleMember is intentionally not used here: PSScriptAnalyzer 1.25 crashes
# (ProvideCommentHelp/GetExportedFunction) on Export-ModuleMember with a variable argument.
