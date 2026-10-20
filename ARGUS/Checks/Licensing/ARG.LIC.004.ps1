Register-ArgusCheck @{
    Id          = 'ARG.LIC.004'
    Title       = 'Users with overlapping licences'
    Area        = 'Licensing'
    Category    = 'Licence hygiene'
    Severity    = 'Medium'
    Description = 'Users with two paid SKUs where every service plan of one SKU is also in the other (from `subscribedSkus.servicePlans`), typically a standalone product or an older suite next to the suite that includes it. The contained SKU is redundant. The comparison uses service plan IDs, so it needs no list of SKU names; free, viral and trial SKUs are ignored as in ARG.LIC.006.'
    Rationale   = 'Overlapping licences usually come from upgrades where the old SKU was never removed, or from two licensing groups that both include the user. The contained seat is paid twice and blocks a seat that could go to someone else.'
    Remediation = @{
        Steps      = "1. For each user, confirm that the larger SKU covers what the user needs.`n2. Remove the redundant SKU, or the user from the licensing group that assigns it.`n3. After upgrades, reduce the quantity of the old SKU at renewal."
        PortalUrl  = 'https://admin.microsoft.com/#/licenses'
    }
    References  = @(
        @{ Title = 'Product names and service plan identifiers for licensing'; Url = 'https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference' }
        @{ Title = 'subscribedSku resource type'; Url = 'https://learn.microsoft.com/en-us/graph/api/resources/subscribedsku' }
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
    Tags        = @('Licensing', 'Cost')
    Test        = {
        param($Context)
        $skus = @($Context.Data['SubscribedSkus'])
        $categories = Get-ArgusSkuCategory -SubscribedSku $skus -Subscription @($Context.Data['Subscriptions']) `
            -IgnoredSku ([string[]]@($Context.Parameters.IgnoredSkus)) -FreeSeatThreshold ([int]$Context.Parameters.FreeSeatThreshold)
        # Service plan ids per paid SKU (lowercase skuId -> set of servicePlanId).
        $plans = @{}
        foreach ($sku in $skus) {
            $id = ([string](Get-ArgusProperty $sku 'skuId' '')).ToLowerInvariant()
            if ($categories[$id] -ne 'Paid') { continue }
            $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($plan in @(Get-ArgusProperty $sku 'servicePlans' @())) {
                $planId = [string](Get-ArgusProperty $plan 'servicePlanId' '')
                if ($planId) { $null = $set.Add($planId) }
            }
            if ($set.Count -gt 0) { $plans[$id] = $set }
        }

        $evaluated = 0
        $findings = foreach ($user in @($Context.Data['Users'])) {
            $assigned = @(Get-ArgusProperty $user 'assignedLicenses' @() | ForEach-Object { ([string](Get-ArgusProperty $_ 'skuId' '')).ToLowerInvariant() } |
                    Where-Object { $plans.ContainsKey($_) } | Sort-Object -Unique)
            if ($assigned.Count -lt 2) { continue }
            $evaluated++
            $redundant = @(foreach ($small in $assigned) {
                    foreach ($large in $assigned) {
                        if ($small -eq $large -or $plans[$small].Count -ge $plans[$large].Count) { continue }
                        if ($plans[$small].IsSubsetOf($plans[$large])) { [pscustomobject]@{ Small = $small; Large = $large }; break }
                    }
                })
            foreach ($pair in $redundant) {
                [pscustomobject]@{
                    DisplayName       = Get-ArgusProperty $user 'displayName' ''
                    UserPrincipalName = Get-ArgusProperty $user 'userPrincipalName' ''
                    RedundantLicence  = @(Get-ArgusSkuName -SkuId @($pair.Small) -SubscribedSku $skus)[0]
                    IncludedIn        = @(Get-ArgusSkuName -SkuId @($pair.Large) -SubscribedSku $skus)[0]
                    ObjectId          = Get-ArgusProperty $user 'id' ''
                }
            }
        }
        $findings = @($findings | Sort-Object UserPrincipalName, RedundantLicence)
        $users = @($findings | Select-Object -ExpandProperty ObjectId -Unique).Count
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -AffectedCount $users -EvaluatedCount $evaluated `
            -Summary "{AffectedCount} of {EvaluatedCount} users with two or more paid SKUs have a licence fully included in another ($($findings.Count) redundant assignments)."
    }
}
