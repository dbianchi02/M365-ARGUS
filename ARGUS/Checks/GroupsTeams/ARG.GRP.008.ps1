Register-ArgusCheck @{
    Id          = 'ARG.GRP.008'
    Title       = 'Inactive Teams (more than {InactiveDays} days)'
    Area        = 'GroupsTeams'
    Category    = 'Lifecycle'
    Severity    = 'Low'
    Description = 'Teams whose `Last Activity Date` in the Teams team activity report (`getTeamsTeamActivityDetail`, period D180) is older than **{InactiveDays}** days, or empty (no activity recorded in the report period). Teams created less than {InactiveDays} days ago and teams that no longer exist are ignored when groups can be read. With concealed report names, or when the report returns no rows, the result is Investigate.'
    Rationale   = 'Inactive Teams keep content, guests and permissions that nobody curates. Archiving or deleting them keeps search, storage and access reviews meaningful.'
    Remediation = @{
        Steps      = "1. Contact the owners of each inactive team and confirm whether it is still needed.`n2. Archive teams whose content must be kept (read-only) and delete the others after your retention period.`n3. Use the group expiration policy (ARG.GRP.003) to automate the review."
        PowerShell = "# Sample only - review before running. Archives one team (read-only).`nConnect-MgGraph -Scopes 'TeamSettings.ReadWrite.All'`nInvoke-MgArchiveTeam -TeamId '<GroupId>'"
        PortalUrl  = 'https://admin.teams.microsoft.com/teams/manage'
    }
    References  = @(
        @{ Title = 'Microsoft Teams team usage report'; Url = 'https://learn.microsoft.com/en-us/microsoftteams/teams-analytics-and-reports/teams-usage-report' }
        @{ Title = 'Archive or restore a team'; Url = 'https://learn.microsoft.com/en-us/microsoftteams/archive-or-delete-a-team' }
    )
    Requires    = @{
        Services         = @('Graph')
        GraphScopes      = @('Reports.Read.All')
        DataSets         = @('TeamsActivity', 'ReportSettings')
        OptionalDataSets = @('Groups')
    }
    Parameters  = @{ InactiveDays = 180 }
    Tags        = @('Teams', 'Lifecycle', 'Reports')
    Test        = {
        param($Context)
        $rows = @($Context.Data['TeamsActivity'])
        $issue = Get-ArgusReportIssue -ReportSettings $Context.Data['ReportSettings'] -Row $rows -ObjectName 'inactive Teams'
        if ($issue) { return New-ArgusResult -Status Investigate -Summary $issue }

        $days = [int]$Context.Parameters.InactiveDays
        $threshold = $Context.Now.AddDays(-$days)
        $groups = $null
        if ($Context.Data.ContainsKey('Groups')) {
            $groups = @{}
            foreach ($group in @($Context.Data['Groups'])) { $groups[([string](Get-ArgusProperty $group 'id' '')).ToLowerInvariant()] = $group }
        }

        $evaluated = 0
        $findings = foreach ($row in $rows) {
            $teamId = ([string](Get-ArgusProperty $row 'Team Id' '')).ToLowerInvariant()
            if ($null -ne $groups) {
                if (-not $groups.ContainsKey($teamId)) { continue }
                $created = ConvertTo-ArgusUtcDate (Get-ArgusProperty $groups[$teamId] 'createdDateTime')
                if ($created -and $created -gt $threshold) { continue }
            }
            $evaluated++
            $last = ConvertTo-ArgusUtcDate (Get-ArgusProperty $row 'Last Activity Date' '')
            if ($last -and $last -ge $threshold) { continue }
            [pscustomobject]@{
                TeamName     = Get-ArgusProperty $row 'Team Name' ''
                TeamType     = Get-ArgusProperty $row 'Team Type' ''
                LastActivity = Format-ArgusDate $last 'None in the last 180 days'
                DaysInactive = if ($last) { [int]($Context.Now - $last).TotalDays } else { $null }
                Guests       = Get-ArgusProperty $row 'Guests' ''
                GroupId      = Get-ArgusProperty $row 'Team Id' ''
            }
        }
        $findings = @($findings | Sort-Object @{ Expression = { if ($null -eq $_.DaysInactive) { [int]::MaxValue } else { $_.DaysInactive } }; Descending = $true }, TeamName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $evaluated `
            -Summary '{AffectedCount} of {EvaluatedCount} Teams have had no activity for {InactiveDays}+ days.'
    }
}
