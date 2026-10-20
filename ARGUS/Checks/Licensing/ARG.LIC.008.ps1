Register-ArgusCheck @{
    Id          = 'ARG.LIC.008'
    Title       = 'Paid licences assigned directly to users'
    Area        = 'Licensing'
    Category    = 'Licence management'
    Severity    = 'Low'
    Description = 'Users with at least one paid licence assigned directly (`licenseAssignmentStates` entry without `assignedByGroup`) instead of through group-based licensing. Free, viral and developer SKUs (the IgnoredSkus list), SKUs with **{FreeSeatThreshold}** or more seats and trial SKUs (`isTrial` in `/directory/subscriptions`) are not counted: they are usually self-service sign-ups. AlsoFromGroup lists the direct licences the user also receives from a group, where the direct assignment is redundant.'
    Rationale   = 'Direct assignments are not driven by group membership: they are not removed when a person changes role or leaves, and they are hard to audit at scale. Group-based licensing keeps paid licences consistent with joiner/mover/leaver processes.'
    Remediation = @{
        Steps      = "1. Create (or reuse) a security group per licence profile and assign the licences to the group.`n2. Add the users to the group and wait for the group assignment to be active.`n3. Remove the direct assignments, starting with the redundant ones listed in AlsoFromGroup."
        PowerShell = "# Sample only - review before running. Removes one directly assigned licence after the group assignment is active.`nConnect-MgGraph -Scopes 'User.ReadWrite.All'`nSet-MgUserLicense -UserId '<ObjectId>' -AddLicenses @() -RemoveLicenses @('<SkuId>')"
        PortalUrl  = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/LicensesMenuBlade/~/Products'
    }
    References  = @(
        @{ Title = 'What is group-based licensing in Microsoft Entra ID?'; Url = 'https://learn.microsoft.com/en-us/entra/fundamentals/concept-group-based-licensing' }
        @{ Title = 'Migrate users from individual licenses to group-based licenses'; Url = 'https://learn.microsoft.com/en-us/entra/identity/users/licensing-groups-migrate-users' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('User.Read.All')
        DataSets    = @('Users', 'SubscribedSkus', 'Subscriptions')
    }
    Parameters  = @{
        FreeSeatThreshold = 10000
        IgnoredSkus       = @($script:ArgusFreeSkus)
    }
    Tags        = @('Licensing', 'Groups')
    Test        = {
        param($Context)
        $skus = @($Context.Data['SubscribedSkus'])
        $categories = Get-ArgusSkuCategory -SubscribedSku $skus -Subscription @($Context.Data['Subscriptions']) `
            -IgnoredSku ([string[]]@($Context.Parameters.IgnoredSkus)) -FreeSeatThreshold ([int]$Context.Parameters.FreeSeatThreshold)
        # SKUs no longer in subscribedSkus are unknown: treat them as paid.
        $isPaid = { param([string] $SkuId) $category = $categories[$SkuId.ToLowerInvariant()]; -not $category -or $category -eq 'Paid' }

        $licensed = @($Context.Data['Users'] | Where-Object { @(Get-ArgusProperty $_ 'licenseAssignmentStates' @()).Count -gt 0 })
        $redundant = 0
        $freeOnly = 0
        $findings = foreach ($user in $licensed) {
            $states = @(Get-ArgusProperty $user 'licenseAssignmentStates' @())
            $direct = @($states | Where-Object { -not (Get-ArgusProperty $_ 'assignedByGroup' '') } | ForEach-Object { [string](Get-ArgusProperty $_ 'skuId' '') } | Select-Object -Unique)
            if ($direct.Count -eq 0) { continue }
            $paid = @($direct | Where-Object { & $isPaid $_ })
            if ($paid.Count -eq 0) { $freeOnly++; continue }
            $fromGroup = @($states | Where-Object { Get-ArgusProperty $_ 'assignedByGroup' '' } | ForEach-Object { [string](Get-ArgusProperty $_ 'skuId' '') })
            $both = @($paid | Where-Object { $_ -in $fromGroup })
            if ($both.Count -gt 0) { $redundant++ }
            [pscustomobject]@{
                DisplayName       = Get-ArgusProperty $user 'displayName' ''
                UserPrincipalName = Get-ArgusProperty $user 'userPrincipalName' ''
                DirectLicences    = @(Get-ArgusSkuName -SkuId $paid -SubscribedSku $skus)
                AlsoFromGroup     = @(Get-ArgusSkuName -SkuId $both -SubscribedSku $skus)
                AccountEnabled    = [bool](Get-ArgusProperty $user 'accountEnabled' $true)
                UserType          = Get-ArgusProperty $user 'userType' ''
                ObjectId          = Get-ArgusProperty $user 'id' ''
            }
        }
        $findings = @($findings | Sort-Object @{ Expression = { @($_.AlsoFromGroup).Count }; Descending = $true }, UserPrincipalName)

        $note = if ($freeOnly) { " $freeOnly more have only free or trial licences assigned directly (not counted)." } else { '' }
        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $licensed.Count -Summary ('No paid licence is assigned directly ({EvaluatedCount} licensed users evaluated).' + $note)
        }
        New-ArgusResult -Status Failed -Findings $findings -EvaluatedCount $licensed.Count `
            -Summary ("{AffectedCount} of {EvaluatedCount} licensed users have paid licences assigned directly; $redundant of them also receive the same licence from a group." + $note)
    }
}
