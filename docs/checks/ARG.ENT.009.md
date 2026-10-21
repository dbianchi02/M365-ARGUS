# ARG.ENT.009 — Directory roles assigned to guests

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
| Tags | Roles, Guests, Privileged access |

## What is checked

Any Microsoft Entra directory role (active, or eligible with Entra ID P2) held by a guest account, directly or through a role-assignable group.

## Why it matters

Administrative roles should be held by accounts the organisation controls. A guest account follows the lifecycle of another tenant: when the person leaves their company, nobody here is notified.

## How to fix

1. Confirm why the guest needs the role (often a supplier or a former consultant).
2. Remove the role assignment from the guest.
3. If the access is still needed, create an internal account for the person, or use a partner relationship (GDAP) for service providers.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running. Removes one role assignment.
Connect-MgGraph -Scopes 'RoleManagement.ReadWrite.Directory'
Remove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId '<AssignmentId>'
```

## References

- [Best practices for Microsoft Entra roles](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/best-practices)
- [Default user permissions (guests)](https://learn.microsoft.com/en-us/entra/fundamentals/users-default-permissions)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
