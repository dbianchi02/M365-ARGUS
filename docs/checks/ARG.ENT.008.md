# ARG.ENT.008 — Global Administrator count outside 2 to 4

| | |
|---|---|
| Area | EntraID |
| Category | Privileged access |
| Severity | High |
| Services | Graph |
| Graph permissions (read-only) | `GroupMember.Read.All`, `RoleEligibilitySchedule.Read.Directory`, `RoleManagement.Read.Directory` |
| Directory roles (delegated) | Global Reader |
| Licences | — |
| Data sets | DirectoryRoles |
| Uses Graph beta | No |
| Tags | Roles, Privileged access |

## What is checked

Counts the distinct holders of the Global Administrator role: active assignments and, with Entra ID P2, eligible (PIM) assignments. Members of role-assignable groups that hold the role are counted individually. Fails when the count is below **2** or above **4**. Global exclusions are not applied: emergency-access accounts must be counted.

## Why it matters

Too few Global Administrators risks losing control of the tenant; too many makes the most powerful role hard to govern. Keep two emergency-access accounts plus a small number of named administrators, and delegate the rest to least-privileged roles.

## How to fix

1. Keep two cloud-only emergency-access accounts with permanent Global Administrator assignments.
2. Move day-to-day administration to least-privileged roles (User, Exchange, SharePoint, Teams Administrator...).
3. With Entra ID P2, make the remaining Global Administrator assignments eligible in PIM instead of permanent.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running. Lists current Global Administrator assignments.
Connect-MgGraph -Scopes 'RoleManagement.Read.Directory'
Get-MgRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '62e90394-69f5-4237-9190-012177145e10'" -ExpandProperty principal
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.ENT.008".Parameters`.

| Name | Default |
|---|---|
| `MaxCount` | 4 |
| `MinCount` | 2 |

## References

- [Best practices for Microsoft Entra roles](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/best-practices)
- [Manage emergency access admin accounts](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-emergency-access)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
