Register-ArgusCheck @{
    Id          = 'ARG.GRP.002'
    Title       = 'Group naming policy configured'
    Area        = 'GroupsTeams'
    Category    = 'Group governance'
    Severity    = 'Low'
    Description = 'Reads `PrefixSuffixNamingRequirement` and `CustomBlockedWordsList` in the tenant-wide Group.Unified directory setting. Passes when a prefix/suffix rule or a blocked-words list is configured. The naming policy requires Microsoft Entra ID P1 for the users it applies to.'
    Rationale   = 'A naming convention (for example a GRP- prefix or a department attribute) makes groups and Teams easy to recognise in the address book, in Teams and in SharePoint; blocked words prevent misleading names.'
    Remediation = @{
        Steps      = "1. Agree on a naming convention (fixed prefix or suffix, or one based on user attributes such as department).`n2. Configure it in the Microsoft Entra admin center: Groups > Naming policy.`n3. Optionally add a list of blocked words."
        PortalUrl  = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/NamingPolicy'
    }
    References  = @(
        @{ Title = 'Microsoft 365 groups naming policy'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/solutions/groups-naming-policy' }
        @{ Title = 'Enforce a group naming policy in Microsoft Entra ID'; Url = 'https://learn.microsoft.com/en-us/entra/identity/users/groups-naming-policy' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('GroupSettings.Read.All')
        Licenses    = @('AAD_PREMIUM')
        DataSets    = @('GroupSettings')
    }
    Tags        = @('Groups', 'Policy')
    Test        = {
        param($Context)
        $settings = @($Context.Data['GroupSettings'])
        $rule = Get-ArgusGroupSettingValue -GroupSettings $settings -Name 'PrefixSuffixNamingRequirement'
        $blocked = Get-ArgusGroupSettingValue -GroupSettings $settings -Name 'CustomBlockedWordsList'
        if ($rule -or $blocked) {
            $parts = [System.Collections.Generic.List[string]]::new()
            if ($rule) { $parts.Add("naming rule '$rule'") }
            if ($blocked) { $parts.Add("$(@($blocked -split ',' | Where-Object { $_.Trim() }).Count) blocked words") }
            return New-ArgusResult -Status Passed -Summary ('A Microsoft 365 group naming policy is configured: ' + ($parts -join ', ') + '.')
        }
        New-ArgusResult -Status Failed -Summary 'No Microsoft 365 group naming policy is configured (no prefix/suffix rule and no blocked words).'
    }
}
