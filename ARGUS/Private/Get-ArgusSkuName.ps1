function Get-ArgusSkuName {
    <#
    .SYNOPSIS
        Returns readable licence names for skuIds, using subscribedSkus and a small built-in name map.

    .DESCRIPTION
        Graph only exposes skuPartNumber (e.g. SPE_E3). Common SKUs are translated to their commercial
        names (from "Product names and service plan identifiers for licensing" on Microsoft Learn);
        other SKUs fall back to skuPartNumber, and unknown skuIds to the id itself.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]] $SkuId,

        [Parameter()]
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]] $SubscribedSku = @()
    )

    $names = @{
        SPE_E3 = 'Microsoft 365 E3'; SPE_E5 = 'Microsoft 365 E5'; SPE_F1 = 'Microsoft 365 F3'
        ENTERPRISEPACK = 'Office 365 E3'; ENTERPRISEPREMIUM = 'Office 365 E5'; STANDARDPACK = 'Office 365 E1'; DESKLESSPACK = 'Office 365 F3'
        SPB = 'Microsoft 365 Business Premium'; O365_BUSINESS_PREMIUM = 'Microsoft 365 Business Standard'; O365_BUSINESS_ESSENTIALS = 'Microsoft 365 Business Basic'
        O365_BUSINESS = 'Microsoft 365 Apps for business'; OFFICESUBSCRIPTION = 'Microsoft 365 Apps for enterprise'
        EXCHANGESTANDARD = 'Exchange Online (Plan 1)'; EXCHANGEENTERPRISE = 'Exchange Online (Plan 2)'; EXCHANGEARCHIVE_ADDON = 'Exchange Online Archiving'
        EMS = 'Enterprise Mobility + Security E3'; EMSPREMIUM = 'Enterprise Mobility + Security E5'
        AAD_PREMIUM = 'Microsoft Entra ID P1'; AAD_PREMIUM_P2 = 'Microsoft Entra ID P2'
        POWER_BI_PRO = 'Power BI Pro'; POWER_BI_STANDARD = 'Power BI (free)'; PBI_PREMIUM_PER_USER = 'Power BI Premium Per User'
        VISIOCLIENT = 'Visio Plan 2'; PROJECTPREMIUM = 'Project Plan 5'; PROJECTPROFESSIONAL = 'Project Plan 3'
        TEAMS_EXPLORATORY = 'Microsoft Teams Exploratory'; FLOW_FREE = 'Power Automate Free'; Microsoft_Teams_Premium = 'Teams Premium'
        INTUNE_A = 'Microsoft Intune Plan 1'; WIN_DEF_ATP = 'Microsoft Defender for Endpoint P2'; MCOEV = 'Teams Phone Standard'
    }

    $partNumbers = @{}
    foreach ($sku in @($SubscribedSku | Where-Object { $_ })) {
        $id = [string](Get-ArgusProperty $sku 'skuId' '')
        if ($id) { $partNumbers[$id.ToLowerInvariant()] = [string](Get-ArgusProperty $sku 'skuPartNumber' '') }
    }

    [string[]]@(foreach ($value in @($SkuId | Where-Object { $_ })) {
            $id = ([string]$value).ToLowerInvariant()
            $part = $partNumbers[$id]
            if (-not $part) { $id }
            elseif ($names.ContainsKey($part)) { $names[$part] }
            else { $part }
        })
}
