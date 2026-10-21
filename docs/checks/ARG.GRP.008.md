# ARG.GRP.008 — Inactive Teams (more than 180 days)

| | |
|---|---|
| Area | GroupsTeams |
| Category | Lifecycle |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `Group.Read.All`, `Reports.Read.All`, `ReportSettings.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader, Reports Reader |
| Licences | — |
| Data sets | TeamsActivity, ReportSettings (optional: Groups) |
| Uses Graph beta | No |
| Tags | Teams, Lifecycle, Reports |

## What is checked

Teams whose `Last Activity Date` in the Teams team activity report (`getTeamsTeamActivityDetail`, period D180) is older than **180** days, or empty (no activity recorded in the report period). Teams created less than 180 days ago and teams that no longer exist are ignored when groups can be read. With concealed report names, or when the report returns no rows, the result is Investigate.

## Why it matters

Inactive Teams keep content, guests and permissions that nobody curates. Archiving or deleting them keeps search, storage and access reviews meaningful.

## How to fix

1. Contact the owners of each inactive team and confirm whether it is still needed.
2. Archive teams whose content must be kept (read-only) and delete the others after your retention period.
3. Use the group expiration policy (ARG.GRP.003) to automate the review.

Portal: <https://admin.teams.microsoft.com/teams/manage>

```powershell
# Sample only - review before running. Archives one team (read-only).
Connect-MgGraph -Scopes 'TeamSettings.ReadWrite.All'
Invoke-MgArchiveTeam -TeamId '<GroupId>'
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.GRP.008".Parameters`.

| Name | Default |
|---|---|
| `InactiveDays` | 180 |

## References

- [Microsoft Teams team usage report](https://learn.microsoft.com/en-us/microsoftteams/teams-analytics-and-reports/teams-usage-report)
- [Archive or restore a team](https://learn.microsoft.com/en-us/microsoftteams/archive-or-delete-a-team)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
