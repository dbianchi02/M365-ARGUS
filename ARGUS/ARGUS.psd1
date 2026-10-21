@{
    RootModule           = 'ARGUS.psm1'
    ModuleVersion        = '1.0.0'
    CompatiblePSEditions = @('Core')
    GUID                 = '83523a0a-cb5f-477a-8882-199f35fd3f4b'
    Author               = 'Davide Bianchi'
    CompanyName          = 'Community'
    Copyright            = '(c) 2026 Davide Bianchi. MIT License.'
    Description          = 'ARGUS - Automated Report & Governance Utility Suite. Runs read-only governance checks against a Microsoft 365 tenant, computes a weighted Governance Score and produces a self-contained HTML report (plus JSON) with findings and remediation guidance.'
    PowerShellVersion    = '7.2'

    RequiredModules      = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0' }
    )

    FunctionsToExport    = @(
        'Connect-Argus'
        'Disconnect-Argus'
        'Test-ArgusPrerequisite'
        'Get-ArgusRequiredPermission'
        'Get-ArgusCheck'
        'New-ArgusConfig'
        'Invoke-Argus'
        'Export-ArgusReport'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Prerelease   = ''
            Tags         = @('M365', 'Microsoft365', 'Governance', 'EntraID', 'SharePoint', 'Teams', 'Exchange', 'Report', 'Graph', 'PSEdition_Core', 'Windows', 'Linux', 'MacOS')
            ProjectUri   = 'https://github.com/dbianchi02/M365-ARGUS'
            LicenseUri   = 'https://github.com/dbianchi02/M365-ARGUS/blob/main/LICENSE'
            ReleaseNotes = 'See https://github.com/dbianchi02/M365-ARGUS/blob/main/CHANGELOG.md'
        }
    }
}
