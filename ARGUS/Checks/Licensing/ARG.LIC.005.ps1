Register-ArgusCheck @{
    Id          = 'ARG.LIC.005'
    Title       = 'Licence assignment errors'
    Area        = 'Licensing'
    Category    = 'Licence hygiene'
    Severity    = 'Medium'
    Description = 'Users whose `licenseAssignmentStates` contain an entry in state **Error** (the licence is not assigned) or **ActiveWithError** (assigned, but part of it failed). The error column shows the reason reported by Microsoft Entra ID, for example CountViolation (not enough seats), MutuallyExclusiveViolation or ProhibitedInUsageLocationViolation. Group names are shown when groups could be read.'
    Rationale   = 'Assignment errors leave users without the services they are expected to have, and usually go unnoticed when licences are assigned through groups.'
    Remediation = @{
        Steps      = "1. Open the group (for group-based licensing) or the user in the Microsoft Entra admin center and read the error.`n2. Fix the cause: buy or free seats (CountViolation), remove the conflicting licence (MutuallyExclusiveViolation), add the missing prerequisite licence (DependencyViolation), or set the usage location.`n3. Reprocess the group or user so the assignment is retried."
        PortalUrl  = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/LicensesMenuBlade/~/Products'
    }
    References  = @(
        @{ Title = 'Identify and resolve license assignment problems for a group'; Url = 'https://learn.microsoft.com/en-us/entra/identity/users/licensing-groups-resolve-problems' }
        @{ Title = 'licenseAssignmentState resource type'; Url = 'https://learn.microsoft.com/en-us/graph/api/resources/licenseassignmentstate' }
    )
    Requires    = @{
        Services         = @('Graph')
        GraphScopes      = @('User.Read.All')
        DataSets         = @('Users', 'SubscribedSkus')
        OptionalDataSets = @('Groups')
    }
    Tags        = @('Licensing')
    Test        = {
        param($Context)
        $skus = @($Context.Data['SubscribedSkus'])
        $groupNames = @{}
        if ($Context.Data.ContainsKey('Groups')) {
            foreach ($group in @($Context.Data['Groups'])) {
                $id = [string](Get-ArgusProperty $group 'id' '')
                if ($id) { $groupNames[$id.ToLowerInvariant()] = [string](Get-ArgusProperty $group 'displayName' '') }
            }
        }

        $licensed = @($Context.Data['Users'] | Where-Object { @(Get-ArgusProperty $_ 'licenseAssignmentStates' @()).Count -gt 0 })
        $findings = foreach ($user in $licensed) {
            foreach ($state in @(Get-ArgusProperty $user 'licenseAssignmentStates' @())) {
                $value = [string](Get-ArgusProperty $state 'state' '')
                if ($value -notin 'Error', 'ActiveWithError') { continue }
                $groupId = [string](Get-ArgusProperty $state 'assignedByGroup' '')
                $assignedBy = if (-not $groupId) { 'Direct' }
                elseif ($groupNames.ContainsKey($groupId.ToLowerInvariant())) { "Group: $($groupNames[$groupId.ToLowerInvariant()])" }
                else { "Group: $groupId" }
                [pscustomobject]@{
                    DisplayName       = Get-ArgusProperty $user 'displayName' ''
                    UserPrincipalName = Get-ArgusProperty $user 'userPrincipalName' ''
                    Licence           = @(Get-ArgusSkuName -SkuId @(Get-ArgusProperty $state 'skuId') -SubscribedSku $skus)[0]
                    State             = $value
                    Error             = Get-ArgusProperty $state 'error' ''
                    AssignedBy        = $assignedBy
                    LastUpdated       = Format-ArgusDate (Get-ArgusProperty $state 'lastUpdatedDateTime')
                    ObjectId          = Get-ArgusProperty $user 'id' ''
                }
            }
        }
        $findings = @($findings | Sort-Object State, Error, UserPrincipalName)

        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $licensed.Count -Summary 'No licence assignment errors ({EvaluatedCount} licensed users evaluated).'
        }
        $users = @($findings | Select-Object -ExpandProperty ObjectId -Unique).Count
        New-ArgusResult -Status Failed -Findings $findings -EvaluatedCount $licensed.Count `
            -Summary "{AffectedCount} licence assignments in error on $users of {EvaluatedCount} licensed users."
    }
}
