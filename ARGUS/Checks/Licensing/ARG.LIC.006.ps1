Register-ArgusCheck @{
    Id          = 'ARG.LIC.006'
    Title       = 'Unused licences per SKU'
    Area        = 'Licensing'
    Category    = 'Cost'
    Severity    = 'Medium'
    Description = 'Compares purchased seats (`prepaidUnits.enabled`) with assigned seats (`consumedUnits`) for every active, user-assignable SKU (`capabilityStatus` = Enabled, `appliesTo` = User). A SKU fails when more than **{UnusedPercent}%** or more than **{UnusedSeats}** seats are unused. Free, viral and developer SKUs (the IgnoredSkus list), SKUs with **{FreeSeatThreshold}** or more seats (free offers are provisioned with very large quantities) and trial SKUs (`isTrial` in `/directory/subscriptions`) are ignored.'
    Rationale   = 'Unused seats are a recurring cost with no business value. Reviewing them before each renewal is the simplest licence saving.'
    Remediation = @{
        Steps      = "1. Confirm the unused seats are not reserved for planned hires or a migration.`n2. Reassign the seats, or reduce the subscription quantity (for annual commitments, at the next renewal).`n3. Review the SKUs regularly, for example monthly."
        PortalUrl  = 'https://admin.microsoft.com/Adminportal/Home#/licenses'
    }
    References  = @(
        @{ Title = 'Buy or remove licenses for a Microsoft business subscription'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/commerce/licenses/buy-licenses' }
        @{ Title = 'Product names and service plan identifiers for licensing'; Url = 'https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('LicenseAssignment.Read.All')
        DataSets    = @('SubscribedSkus', 'Subscriptions')
    }
    Parameters  = @{
        UnusedPercent     = 10
        UnusedSeats       = 5
        FreeSeatThreshold = 10000
        IgnoredSkus       = @($script:ArgusFreeSkus)
    }
    Tags        = @('Licensing', 'Cost')
    Test        = {
        param($Context)
        $maxPercent = [double]$Context.Parameters.UnusedPercent
        $maxSeats = [int]$Context.Parameters.UnusedSeats
        $skus = @($Context.Data['SubscribedSkus'])
        $categories = Get-ArgusSkuCategory -SubscribedSku $skus -Subscription @($Context.Data['Subscriptions']) `
            -IgnoredSku ([string[]]@($Context.Parameters.IgnoredSkus)) -FreeSeatThreshold ([int]$Context.Parameters.FreeSeatThreshold)

        $evaluated = @($skus | Where-Object {
                (Get-ArgusProperty $_ 'capabilityStatus' '') -eq 'Enabled' -and
                (Get-ArgusProperty $_ 'appliesTo' '') -eq 'User' -and
                [int](Get-ArgusProperty $_ 'prepaidUnits.enabled' 0) -gt 0 -and
                $categories[([string](Get-ArgusProperty $_ 'skuId' '')).ToLowerInvariant()] -eq 'Paid'
            })

        $findings = @($evaluated | ForEach-Object {
                $purchased = [int](Get-ArgusProperty $_ 'prepaidUnits.enabled' 0)
                $assigned = [int](Get-ArgusProperty $_ 'consumedUnits' 0)
                $unused = [math]::Max(0, $purchased - $assigned)
                $percent = [math]::Round(100.0 * $unused / $purchased, 1)
                if ($unused -gt 0 -and ($percent -gt $maxPercent -or $unused -gt $maxSeats)) {
                    [pscustomobject]@{
                        Sku           = @(Get-ArgusSkuName -SkuId @(Get-ArgusProperty $_ 'skuId') -SubscribedSku $skus)[0]
                        SkuPartNumber = Get-ArgusProperty $_ 'skuPartNumber' ''
                        Purchased     = $purchased
                        Assigned      = $assigned
                        Unused        = $unused
                        UnusedPercent = $percent
                    }
                }
            } | Sort-Object Unused -Descending)

        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        $unusedTotal = 0
        foreach ($finding in $findings) { $unusedTotal += $finding.Unused }
        $summary = if ($findings.Count -gt 0) { "{AffectedCount} of {EvaluatedCount} paid SKUs have more than {UnusedPercent}% or more than {UnusedSeats} seats unused ($unusedTotal unused seats in total)." }
        else { 'All {EvaluatedCount} paid SKUs are within {UnusedPercent}% / {UnusedSeats} unused seats.' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $evaluated.Count -Summary $summary
    }
}
