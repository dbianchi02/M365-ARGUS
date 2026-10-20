Register-ArgusCheck @{
    Id          = 'ARG.LIC.007'
    Title       = 'Shared mailboxes with a licence'
    Area        = 'Licensing'
    Category    = 'Cost'
    Severity    = 'Low'
    Description = 'Shared mailboxes (Exchange Online) whose user object has licences assigned. A shared mailbox needs a licence only when it is larger than 50 GB, has an online archive, or is on litigation hold or an in-place hold. Mailboxes that meet one of these conditions (size of **{SizeThresholdGB}** GB or more, archive active, `LitigationHoldEnabled`, non-empty `InPlaceHolds`) are not listed; the others are returned for review (Investigate), because organisation-wide retention policies and other needs are not visible to this check.'
    Rationale   = 'Shared mailboxes are often licensed when a user mailbox is converted and the licence is never removed: a recurring cost with no benefit.'
    Remediation = @{
        Steps      = "1. Confirm the mailbox does not need a licence (size, archive, holds, retention or other services such as Intune).`n2. Remove the licence from the user object, or remove it from the licensing group.`n3. If the mailbox needs an archive or a hold, consider Exchange Online Plan 2 or the Exchange Online Archiving add-on instead of a full suite."
        PortalUrl  = 'https://admin.microsoft.com/Adminportal/Home#/SharedMailbox'
    }
    References  = @(
        @{ Title = 'About shared mailboxes'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/email/about-shared-mailboxes' }
        @{ Title = 'Exchange Online limits: mailbox storage limits'; Url = 'https://learn.microsoft.com/en-us/office365/servicedescriptions/exchange-online-service-description/exchange-online-limits' }
    )
    Requires    = @{
        Services    = @('Graph', 'Exchange')
        GraphScopes = @('User.Read.All')
        DataSets    = @('Users', 'SubscribedSkus', 'Mailboxes')
    }
    Parameters  = @{ SizeThresholdGB = 50 }
    Tags        = @('Licensing', 'Exchange', 'Cost')
    Test        = {
        param($Context)
        $threshold = [double]$Context.Parameters.SizeThresholdGB
        $skus = @($Context.Data['SubscribedSkus'])
        $users = @{}
        foreach ($user in @($Context.Data['Users'])) {
            $id = [string](Get-ArgusProperty $user 'id' '')
            if ($id) { $users[$id.ToLowerInvariant()] = $user }
        }

        $shared = @($Context.Data['Mailboxes'] | Where-Object { (Get-ArgusProperty $_ 'RecipientTypeDetails' '') -eq 'SharedMailbox' })
        $licensed = 0
        $justified = 0
        $findings = foreach ($mailbox in $shared) {
            $id = ([string](Get-ArgusProperty $mailbox 'ExternalDirectoryObjectId' '')).ToLowerInvariant()
            if (-not $id -or -not $users.ContainsKey($id)) { continue }
            $user = $users[$id]
            $licences = @(Get-ArgusProperty $user 'assignedLicenses' @())
            if ($licences.Count -eq 0) { continue }
            $licensed++

            $archive = (Get-ArgusProperty $mailbox 'ArchiveStatus' '') -eq 'Active'
            $litigation = [bool](Get-ArgusProperty $mailbox 'LitigationHoldEnabled' $false)
            $holds = @(Get-ArgusProperty $mailbox 'InPlaceHolds' @() | Where-Object { $_ }).Count -gt 0
            if ($archive -or $litigation -or $holds) { $justified++; continue }
            $size = Get-ArgusMailboxSize -Identity $id
            if ($null -ne $size -and $size -ge $threshold) { $justified++; continue }

            [pscustomobject]@{
                DisplayName       = Get-ArgusProperty $mailbox 'DisplayName' ''
                UserPrincipalName = Get-ArgusProperty $user 'userPrincipalName' ''
                Licences          = @(Get-ArgusSkuName -SkuId @($licences | ForEach-Object { Get-ArgusProperty $_ 'skuId' }) -SubscribedSku $skus)
                MailboxSizeGB     = if ($null -ne $size) { $size } else { 'Unknown' }
                ObjectId          = Get-ArgusProperty $user 'id' ''
            }
        }
        $findings = @($findings | Sort-Object DisplayName)

        $note = if ($justified) { " ($justified more are justified by size, archive or hold)" } else { '' }
        if ($findings.Count -eq 0) {
            $summary = if ($licensed) { "All $licensed licensed shared mailboxes need their licence (size, archive or hold); {EvaluatedCount} shared mailboxes evaluated." }
            else { 'None of the {EvaluatedCount} shared mailboxes has a licence.' }
            return New-ArgusResult -Status Passed -EvaluatedCount $shared.Count -Summary $summary
        }
        New-ArgusResult -Status Investigate -Findings $findings -EvaluatedCount $shared.Count `
            -Summary ('{AffectedCount} of {EvaluatedCount} shared mailboxes have a licence with no size, archive or hold that requires it' + $note + '.')
    }
}
