Register-ArgusCheck @{
    Id          = 'ARG.LIC.001'
    Title       = 'Disabled users that still have licences'
    Area        = 'Licensing'
    Category    = 'Licence hygiene'
    Severity    = 'High'
    Description = 'Disabled accounts (`accountEnabled` = false) with at least one licence. Shared, room and equipment mailboxes are excluded using Exchange Online (they are disabled by design and may legitimately need a licence). When Exchange Online is not connected they cannot be told apart, so the result is Investigate.'
    Rationale   = 'A licence on a disabled account is paid for but cannot be used. Leavers are the most common cause.'
    Remediation = @{
        Steps      = "1. Check whether the mailbox must be kept (convert it to a shared mailbox, or apply a litigation hold / retention policy first).`n2. Remove the licences, or remove the user from the licensing group.`n3. Delete the account after your retention period."
        PowerShell = "# Sample only - review before running. Removes all licences from one user.`nConnect-MgGraph -Scopes 'User.ReadWrite.All'`n`$skus = (Get-MgUserLicenseDetail -UserId '<ObjectId>').SkuId`nSet-MgUserLicense -UserId '<ObjectId>' -AddLicenses @() -RemoveLicenses `$skus"
        PortalUrl  = 'https://admin.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Assign or unassign licenses for users in the Microsoft 365 admin center'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/manage/assign-licenses-to-users' }
        @{ Title = 'About shared mailboxes'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/email/about-shared-mailboxes' }
    )
    Requires    = @{
        Services         = @('Graph')
        GraphScopes      = @('User.Read.All')
        DataSets         = @('Users', 'SubscribedSkus')
        OptionalDataSets = @('Mailboxes')
    }
    Tags        = @('Licensing', 'Lifecycle', 'Cost')
    Test        = {
        param($Context)
        $skus = @($Context.Data['SubscribedSkus'])
        $haveMailboxes = $Context.Data.ContainsKey('Mailboxes')
        $resourceMailboxes = @{}
        if ($haveMailboxes) {
            foreach ($mailbox in @($Context.Data['Mailboxes'])) {
                $type = [string](Get-ArgusProperty $mailbox 'RecipientTypeDetails' '')
                $id = [string](Get-ArgusProperty $mailbox 'ExternalDirectoryObjectId' '')
                if ($id -and $type -in 'SharedMailbox', 'RoomMailbox', 'EquipmentMailbox') { $resourceMailboxes[$id.ToLowerInvariant()] = $type }
            }
        }

        $disabled = @($Context.Data['Users'] | Where-Object { (Get-ArgusProperty $_ 'accountEnabled') -eq $false })
        $excluded = 0
        $findings = foreach ($user in $disabled) {
            $licences = @(Get-ArgusProperty $user 'assignedLicenses' @())
            if ($licences.Count -eq 0) { continue }
            $id = [string](Get-ArgusProperty $user 'id' '')
            if ($resourceMailboxes.ContainsKey($id.ToLowerInvariant())) { $excluded++; continue }
            [pscustomobject]@{
                DisplayName       = Get-ArgusProperty $user 'displayName' ''
                UserPrincipalName = Get-ArgusProperty $user 'userPrincipalName' ''
                Licences          = @(Get-ArgusSkuName -SkuId @($licences | ForEach-Object { Get-ArgusProperty $_ 'skuId' }) -SubscribedSku $skus)
                UserType          = Get-ArgusProperty $user 'userType' ''
                SyncedFromOnPrem  = [bool](Get-ArgusProperty $user 'onPremisesSyncEnabled' $false)
                ObjectId          = $id
            }
        }
        $findings = @($findings)

        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $disabled.Count -Summary 'None of the {EvaluatedCount} disabled accounts has a licence.'
        }
        if ($haveMailboxes) {
            $note = if ($excluded) { " ($excluded shared, room or equipment mailboxes excluded)" } else { '' }
            return New-ArgusResult -Status Failed -Findings $findings -EvaluatedCount $disabled.Count `
                -Summary ('{AffectedCount} of {EvaluatedCount} disabled accounts still have licences assigned' + $note + '.')
        }
        New-ArgusResult -Status Investigate -Findings $findings -EvaluatedCount $disabled.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} disabled accounts still have licences assigned. Exchange Online is not connected, so shared, room and equipment mailboxes could not be excluded: review the list.'
    }
}
