# ARG.GRP.001 — Microsoft 365 group creation is restricted

| | |
|---|---|
| Area | GroupsTeams |
| Category | Group governance |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `GroupSettings.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | GroupSettings |
| Uses Graph beta | No |
| Tags | Groups, Policy |

## What is checked

Reads `EnableGroupCreation` and `GroupCreationAllowedGroupId` in the tenant-wide Group.Unified directory setting. When the setting was never created every user can create Microsoft 365 groups and Teams (default). Unrestricted creation is Investigate: it is a valid choice for some organisations, provided ownership and expiration are governed.

## Why it matters

Every new Team or Planner plan creates a Microsoft 365 group with a mailbox and a SharePoint site. Without a creation policy, sprawl and duplicates grow quickly; restricting creation to trained users or adding a request process keeps it governed.

## How to fix

1. Decide whether creation is open, restricted to a security group, or done through a request process.
2. To restrict it, create a security group of allowed creators and set EnableGroupCreation = false and GroupCreationAllowedGroupId in the Group.Unified setting.
3. If creation stays open, make sure ARG.GRP.004 (owners) and ARG.GRP.003 (expiration) pass.

Portal: <https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/General>

## References

- [Manage who can create Microsoft 365 Groups](https://learn.microsoft.com/en-us/microsoft-365/solutions/manage-creation-of-groups)
- [Configure group settings using PowerShell](https://learn.microsoft.com/en-us/entra/identity/users/groups-settings-cmdlets)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
