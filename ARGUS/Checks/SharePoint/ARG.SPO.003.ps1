Register-ArgusCheck @{
    Id          = 'ARG.SPO.003'
    Title       = 'Default sharing link is limited to specific people'
    Area        = 'SharePoint'
    Category    = 'Sharing'
    Severity    = 'Medium'
    Description = 'Reads the default link type of the sharing dialog with PnP.PowerShell (`Get-PnPTenant`): `CoreDefaultShareLinkScope` for SharePoint and `OneDriveDefaultShareLinkScope` for OneDrive, falling back to `DefaultSharingLinkType` when they are Uninitialized. Anyone as default fails; People in your organisation (or the widest allowed link) is Investigate; Specific people passes. Needs `Connect-Argus -Service SharePoint`; otherwise the check is Skipped.'
    Rationale   = 'Most people accept the default link. A default of Anyone or of the whole organisation turns every quick share into broad access, which is the main source of oversharing that Copilot later surfaces in answers. Specific people as default keeps sharing intentional.'
    Remediation = @{
        Steps      = "1. In the SharePoint admin center, go to Policies > Sharing > File and folder links.`n2. Set the default link type to Specific people (only the people the user specifies).`n3. Set the default permission to View where editing is not the usual need."
        PowerShell = "# Sample only - review before running.`nConnect-PnPOnline -Url 'https://<tenant>-admin.sharepoint.com' -Interactive -ClientId '<app id>'`nSet-PnPTenant -DefaultSharingLinkType Direct"
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=sharing&modern=true'
    }
    References  = @(
        @{ Title = 'Change the default link type for SharePoint and OneDrive'; Url = 'https://learn.microsoft.com/en-us/sharepoint/change-default-sharing-link' }
        @{ Title = 'Set-SPOTenant: DefaultSharingLinkType and CoreDefaultShareLinkScope'; Url = 'https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant' }
    )
    Requires    = @{
        Services = @('Graph', 'SharePoint')
        DataSets = @('SharePointTenant')
    }
    Tags        = @('SharePoint', 'OneDrive', 'Sharing', 'Oversharing')
    Test        = {
        param($Context)
        $tenant = $Context.Data['SharePointTenant']
        if ($null -eq $tenant) { return New-ArgusResult -Status Investigate -Summary 'The SharePoint sharing settings could not be read.' }
        # DefaultSharingLinkType values mapped to the newer SharingScope names.
        $legacy = @{ None = 'Widest allowed'; Direct = 'SpecificPeople'; Internal = 'Organization'; AnonymousAccess = 'Anyone' }
        $fallback = [string](Get-ArgusProperty $tenant 'DefaultSharingLinkType' '')
        $fallbackScope = if ($legacy.ContainsKey($fallback)) { $legacy[$fallback] } else { $fallback }
        $rank = @{ Anyone = 'Failed'; 'Widest allowed' = 'Investigate'; Organization = 'Investigate'; SpecificPeople = 'Passed' }
        $rows = @(
            foreach ($scope in @(@('SharePoint', 'CoreDefaultShareLinkScope'), @('OneDrive', 'OneDriveDefaultShareLinkScope'))) {
                $value = [string](Get-ArgusProperty $tenant $scope[1] '')
                $effective = if (-not $value -or $value -eq 'Uninitialized') { $fallbackScope } else { $value }
                [pscustomobject]@{
                    Service       = $scope[0]
                    DefaultLink   = $effective
                    Source        = if (-not $value -or $value -eq 'Uninitialized') { "DefaultSharingLinkType = $fallback" } else { "$($scope[1]) = $value" }
                    Permission    = Get-ArgusProperty $tenant 'DefaultLinkPermission' ''
                    Outcome       = if ($rank.ContainsKey($effective)) { $rank[$effective] } else { 'Investigate' }
                }
            }
        )
        $findings = @($rows | Where-Object Outcome -NE 'Passed')
        $status = if ($findings | Where-Object Outcome -EQ 'Failed') { 'Failed' } elseif ($findings) { 'Investigate' } else { 'Passed' }
        $summary = switch ($status) {
            'Failed' { 'The default sharing link is Anyone for {AffectedCount} of {EvaluatedCount} services.' }
            'Investigate' { 'The default sharing link is wider than Specific people for {AffectedCount} of {EvaluatedCount} services.' }
            default { 'The default sharing link is Specific people for SharePoint and OneDrive.' }
        }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $rows.Count -Summary $summary
    }
}
