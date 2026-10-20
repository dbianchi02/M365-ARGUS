Register-ArgusCheck @{
    Id          = 'ARG.LIC.003'
    Title       = 'Paid licences assigned to guest users'
    Area        = 'Licensing'
    Category    = 'Licence hygiene'
    Severity    = 'Medium'
    Description = 'Guest users (`userType` = Guest) with at least one paid licence. Free, viral and trial SKUs are ignored (`IgnoredSkus`, trial subscriptions from `/directory/subscriptions`), as in ARG.LIC.006. Guests normally work with the licences of their home organisation or with the B2B allowance; a paid seat on a guest is usually a mistake or a leftover.'
    Rationale   = 'Licences assigned to guests cost a full seat, are rarely reviewed and often stay after the collaboration ends. When a guest really needs a licence, it should be a documented decision with a sponsor, not the side effect of a group-based assignment.'
    Remediation = @{
        Steps      = "1. Check why each guest has the licence (direct assignment or a licensing group that includes guests).`n2. Remove the licence, or exclude guests from the licensing group (for example with a dynamic group rule on userType).`n3. When a guest needs a licence on purpose, record the decision and the sponsor."
        PowerShell = "# Sample only - review before running.`nConnect-MgGraph -Scopes 'User.ReadWrite.All'`nSet-MgUserLicense -UserId '<guest id>' -AddLicenses @() -RemoveLicenses @('<skuId>')"
        PortalUrl  = 'https://admin.microsoft.com/#/licenses'
    }
    References  = @(
        @{ Title = 'Microsoft Entra External ID B2B licensing'; Url = 'https://learn.microsoft.com/en-us/entra/external-id/external-identities-pricing' }
        @{ Title = 'Assign or remove licenses for user accounts'; Url = 'https://learn.microsoft.com/en-us/entra/fundamentals/license-users-groups' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('User.Read.All', 'LicenseAssignment.Read.All')
        DataSets    = @('Users', 'SubscribedSkus', 'Subscriptions')
    }
    Parameters  = @{
        FreeSeatThreshold = 10000
        IgnoredSkus       = @($script:ArgusFreeSkus)
    }
    Tags        = @('Licensing', 'Guests', 'Cost')
    Test        = {
        param($Context)
        $skus = @($Context.Data['SubscribedSkus'])
        $categories = Get-ArgusSkuCategory -SubscribedSku $skus -Subscription @($Context.Data['Subscriptions']) `
            -IgnoredSku ([string[]]@($Context.Parameters.IgnoredSkus)) -FreeSeatThreshold ([int]$Context.Parameters.FreeSeatThreshold)
        $guests = @($Context.Data['Users'] | Where-Object { (Get-ArgusProperty $_ 'userType' '') -eq 'Guest' })
        $findings = @($guests | ForEach-Object {
                $assigned = @(Get-ArgusProperty $_ 'assignedLicenses' @() | ForEach-Object { [string](Get-ArgusProperty $_ 'skuId' '') })
                $paid = @($assigned | Where-Object { $_ -and $categories[$_.ToLowerInvariant()] -eq 'Paid' })
                if ($paid.Count -eq 0) { return }
                [pscustomobject]@{
                    DisplayName       = Get-ArgusProperty $_ 'displayName' ''
                    UserPrincipalName = Get-ArgusProperty $_ 'userPrincipalName' ''
                    Licences          = @(Get-ArgusSkuName -SkuId $paid -SubscribedSku $skus)
                    AccountEnabled    = [bool](Get-ArgusProperty $_ 'accountEnabled' $false)
                    ObjectId          = Get-ArgusProperty $_ 'id' ''
                }
            } | Sort-Object UserPrincipalName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $guests.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} guest users have a paid licence.'
    }
}
