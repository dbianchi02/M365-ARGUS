Register-ArgusCheck @{
    Id              = 'ARG.ENT.007'
    Title           = 'At least {MinCount} emergency access (break-glass) accounts'
    Area            = 'EntraID'
    Category        = 'Privileged access'
    Severity        = 'High'
    Description     = 'Looks for emergency access accounts: the accounts listed in the Accounts parameter (UPNs or object ids) or, when the list is empty, users whose UPN or display name matches NamePatterns. An account is compliant when it follows the configuration requirements Microsoft documents: enabled, member, cloud-only (not synchronised), UPN on a `*.onmicrosoft.com` domain, and an **active** Global Administrator assignment made directly to the account (not only eligible in PIM, not through a group). Fails when fewer than **{MinCount}** compliant accounts exist. Authentication methods, Conditional Access exclusions and sign-in alerting are part of the same guidance but are security controls outside the scope of ARGUS: verify them separately. Global exclusions are not applied.'
    Rationale       = 'Emergency access accounts prevent the organisation from being locked out of its tenant when federation, MFA or the usual administrators are unavailable. Microsoft recommends two or more, cloud-only, with a permanent active Global Administrator assignment.'
    Remediation     = @{
        Steps      = "1. Create two cloud-only accounts on the *.onmicrosoft.com domain, not tied to a person (for example breakglass01@contoso.onmicrosoft.com).`n2. Assign Global Administrator directly and as active permanent (not eligible) in PIM.`n3. Register phishing-resistant credentials (passkey/FIDO2 or certificate) different from the ones used by daily administrators, store them in separate safe locations, exclude the accounts from blocking Conditional Access policies and alert on every sign-in.`n4. List the accounts in this check's Accounts parameter and test them at least every 90 days."
        PortalUrl  = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RolesManagementMenuBlade/~/AllRoles'
    }
    References      = @(
        @{ Title = 'Manage emergency access admin accounts in Microsoft Entra ID'; Url = 'https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-emergency-access' }
        @{ Title = 'Best practices for Microsoft Entra roles'; Url = 'https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/best-practices' }
    )
    Requires        = @{
        Services    = @('Graph')
        GraphScopes = @('User.Read.All', 'RoleManagement.Read.Directory', 'GroupMember.Read.All')
        DataSets    = @('Users', 'DirectoryRoles')
    }
    Parameters      = @{
        MinCount     = 2
        Accounts     = @()
        NamePatterns = @('*breakglass*', '*break-glass*', '*break.glass*', '*emergency*')
    }
    Tags            = @('Roles', 'Privileged access', 'Resilience')
    ApplyExclusions = $false
    Test            = {
        param($Context)
        $globalAdmin = '62e90394-69f5-4237-9190-012177145e10'
        $configured = @($Context.Parameters.Accounts | Where-Object { $_ } | ForEach-Object { ([string]$_).ToLowerInvariant() })
        $patterns = [string[]]@($Context.Parameters.NamePatterns | Where-Object { $_ })
        $users = @($Context.Data['Users'])

        $candidates = @($users | Where-Object {
                $upn = [string](Get-ArgusProperty $_ 'userPrincipalName' '')
                $name = [string](Get-ArgusProperty $_ 'displayName' '')
                if ($configured.Count -gt 0) {
                    $upn.ToLowerInvariant() -in $configured -or ([string](Get-ArgusProperty $_ 'id' '')).ToLowerInvariant() -in $configured
                }
                else {
                    @($patterns | Where-Object { $upn -like $_ -or $name -like $_ }).Count -gt 0
                }
            })
        $source = if ($configured.Count -gt 0) { 'listed in the Accounts parameter' } else { 'matching NamePatterns (no account listed in the Accounts parameter)' }

        $roleRows = @(Get-ArgusRoleMember -DirectoryRoles $Context.Data['DirectoryRoles'] -RoleTemplateId $globalAdmin)
        $findings = @($candidates | ForEach-Object {
                $id = [string](Get-ArgusProperty $_ 'id' '')
                $upn = [string](Get-ArgusProperty $_ 'userPrincipalName' '')
                $rows = @($roleRows | Where-Object { $_.PrincipalId -eq $id })
                $directActive = @($rows | Where-Object { $_.Assignment -eq 'Active' -and $_.Via -eq 'Direct' }).Count -gt 0
                $globalAdminText = if ($directActive) { 'Active (direct)' }
                elseif (@($rows | Where-Object Assignment -EQ 'Active').Count -gt 0) { 'Active (through a group)' }
                elseif ($rows.Count -gt 0) { 'Eligible only' }
                else { 'No' }

                $issues = [System.Collections.Generic.List[string]]::new()
                if ((Get-ArgusProperty $_ 'accountEnabled') -ne $true) { $issues.Add('disabled') }
                if ((Get-ArgusProperty $_ 'userType' 'Member') -ne 'Member') { $issues.Add('not a member account') }
                if ((Get-ArgusProperty $_ 'onPremisesSyncEnabled') -eq $true) { $issues.Add('synchronised from on-premises') }
                if ($upn -notlike '*.onmicrosoft.com') { $issues.Add('UPN not on *.onmicrosoft.com') }
                if (-not $directActive) { $issues.Add('no direct active Global Administrator assignment') }
                $last = Get-ArgusUserLastSignIn -User $_

                [pscustomobject]@{
                    DisplayName        = Get-ArgusProperty $_ 'displayName' ''
                    UserPrincipalName  = $upn
                    Compliant          = if ($issues.Count -eq 0) { 'Yes' } else { 'No' }
                    Issues             = $issues -join '; '
                    GlobalAdmin        = $globalAdminText
                    CloudOnly          = (Get-ArgusProperty $_ 'onPremisesSyncEnabled') -ne $true
                    LastSignIn         = Format-ArgusDate $last 'Never or unknown'
                    ObjectId           = $id
                }
            } | Sort-Object Compliant, DisplayName)

        $min = [int]$Context.Parameters.MinCount
        $compliant = @($findings | Where-Object Compliant -EQ 'Yes').Count
        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Failed -EvaluatedCount $users.Count -AffectedCount 0 `
                -Summary "No emergency access account found ($source). List the accounts in the Accounts parameter of ARG.ENT.007 if they exist under other names."
        }
        $status = if ($compliant -ge $min) { 'Passed' } else { 'Failed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $findings.Count -AffectedCount ($findings.Count - $compliant) `
            -Summary "$compliant of $($findings.Count) emergency access accounts ($source) meet the requirements; at least {MinCount} are needed."
    }
}
