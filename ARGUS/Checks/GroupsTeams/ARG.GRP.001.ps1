Register-ArgusCheck @{
    Id          = 'ARG.GRP.001'
    Title       = 'Microsoft 365 group creation is restricted'
    Area        = 'GroupsTeams'
    Category    = 'Group governance'
    Severity    = 'Medium'
    Description = 'Reads `EnableGroupCreation` and `GroupCreationAllowedGroupId` in the tenant-wide Group.Unified directory setting. When the setting was never created every user can create Microsoft 365 groups and Teams (default). Unrestricted creation is Investigate: it is a valid choice for some organisations, provided ownership and expiration are governed.'
    Rationale   = 'Every new Team or Planner plan creates a Microsoft 365 group with a mailbox and a SharePoint site. Without a creation policy, sprawl and duplicates grow quickly; restricting creation to trained users or adding a request process keeps it governed.'
    Remediation = @{
        Steps      = "1. Decide whether creation is open, restricted to a security group, or done through a request process.`n2. To restrict it, create a security group of allowed creators and set EnableGroupCreation = false and GroupCreationAllowedGroupId in the Group.Unified setting.`n3. If creation stays open, make sure ARG.GRP.004 (owners) and ARG.GRP.003 (expiration) pass."
        PortalUrl  = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/General'
    }
    References  = @(
        @{ Title = 'Manage who can create Microsoft 365 Groups'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/solutions/manage-creation-of-groups' }
        @{ Title = 'Configure group settings using PowerShell'; Url = 'https://learn.microsoft.com/en-us/entra/identity/users/groups-settings-cmdlets' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('GroupSettings.Read.All')
        DataSets    = @('GroupSettings')
    }
    Tags        = @('Groups', 'Policy')
    Test        = {
        param($Context)
        $settings = @($Context.Data['GroupSettings'])
        $value = Get-ArgusGroupSettingValue -GroupSettings $settings -Name 'EnableGroupCreation'
        $allowedGroup = Get-ArgusGroupSettingValue -GroupSettings $settings -Name 'GroupCreationAllowedGroupId'
        if ($value -eq 'false') {
            $who = if ($allowedGroup) { "only members of group $allowedGroup and administrators" } else { 'only administrators' }
            return New-ArgusResult -Status Passed -Summary "Microsoft 365 group creation is restricted: $who can create groups and Teams."
        }
        $source = if ($null -eq $value) { 'the Group.Unified setting is not configured, so the default applies' } else { 'EnableGroupCreation = true' }
        New-ArgusResult -Status Investigate -Summary "All users can create Microsoft 365 groups and Teams ($source). Confirm this is intended and that ownership and expiration are governed."
    }
}
