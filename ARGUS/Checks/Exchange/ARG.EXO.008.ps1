Register-ArgusCheck @{
    Id          = 'ARG.EXO.008'
    Title       = 'User mailboxes without a mailbox hold (informational)'
    Area        = 'Exchange'
    Category    = 'Retention governance'
    Severity    = 'Info'
    Description = 'Counts user mailboxes with Litigation Hold (`LitigationHoldEnabled`) or an in-place, eDiscovery or retention hold listed in `InPlaceHolds`, and lists the ones with neither. Organisation-wide Microsoft Purview retention policies are not visible to ARGUS (they need the Security & Compliance PowerShell), so a mailbox without a mailbox hold may still be retained: this check is always To review when such mailboxes exist. Info severity: it does not change the score.'
    Rationale   = 'Whether mail must be preserved, for how long and for whom, is a records-management decision. Holds set mailbox by mailbox drift over time; knowing which mailboxes have one, and confirming that a retention policy covers the others, keeps the retention strategy consistent with legal requirements.'
    Remediation = @{
        Steps      = "1. In the Microsoft Purview portal, check the retention policies that include Exchange mailboxes (Data lifecycle management > Policies > Retention policies).`n2. If an organisation-wide policy covers all mailboxes, no mailbox hold is needed; document it.`n3. Otherwise, apply a retention policy or Litigation Hold to the mailboxes that must be preserved."
        PortalUrl  = 'https://purview.microsoft.com/datalifecyclemanagement/retention'
    }
    References  = @(
        @{ Title = 'Learn about retention policies and retention labels'; Url = 'https://learn.microsoft.com/en-us/purview/retention' }
        @{ Title = 'Place a mailbox on Litigation Hold'; Url = 'https://learn.microsoft.com/en-us/purview/ediscovery-create-a-litigation-hold' }
    )
    Requires    = @{
        Services = @('Graph', 'Exchange')
        DataSets = @('Mailboxes')
    }
    Tags        = @('Exchange', 'Mailboxes', 'Retention', 'Inventory')
    Test        = {
        param($Context)
        $mailboxes = @($Context.Data['Mailboxes'] | Where-Object { (Get-ArgusProperty $_ 'RecipientTypeDetails' '') -eq 'UserMailbox' })
        $held = @($mailboxes | Where-Object { (Get-ArgusProperty $_ 'LitigationHoldEnabled' $false) -eq $true -or @(Get-ArgusProperty $_ 'InPlaceHolds' @()).Count -gt 0 })
        $findings = @($mailboxes | Where-Object { $_ -notin $held } | ForEach-Object {
                [pscustomobject]@{
                    DisplayName        = Get-ArgusProperty $_ 'DisplayName' ''
                    UserPrincipalName  = Get-ArgusProperty $_ 'UserPrincipalName' ''
                    PrimarySmtpAddress = Get-ArgusProperty $_ 'PrimarySmtpAddress' ''
                    ArchiveStatus      = Get-ArgusProperty $_ 'ArchiveStatus' ''
                    ObjectId           = Get-ArgusProperty $_ 'ExternalDirectoryObjectId' ''
                }
            } | Sort-Object UserPrincipalName)
        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $mailboxes.Count -AffectedCount 0 -Summary 'All {EvaluatedCount} user mailboxes have a Litigation Hold or another mailbox hold.'
        }
        New-ArgusResult -Status Investigate -Findings $findings -EvaluatedCount $mailboxes.Count `
            -Summary "$($held.Count) of {EvaluatedCount} user mailboxes have a mailbox hold; {AffectedCount} have none. Confirm in Microsoft Purview that a retention policy covers them."
    }
}
