# ARG.ENT.002 — Licensed users without manager or department

| | |
|---|---|
| Area | EntraID |
| Category | Identity lifecycle |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | Users, UserManagers |
| Uses Graph beta | No |
| Tags | Users, Lifecycle, DataQuality |

## What is checked

Enabled member users with at least one licence whose `manager` or `department` is empty in Microsoft Entra ID (`GET /users?$expand=manager`). Accounts without licences (service, shared and emergency accounts) are not evaluated; use the global exclusions for licensed accounts that are not people.

## Why it matters

Manager and department drive access reviews, approval workflows, dynamic groups, the organisation chart and the people Copilot considers relevant. Missing values usually mean the HR provisioning or the joiner process skipped a step, and they make every later governance step manual.

## How to fix

1. Fix the source: when users are synchronised or provisioned from HR, complete manager and department there.
2. For cloud-only users, set them in the Microsoft Entra admin center (Users > user > Properties > Job information).
3. Make both attributes mandatory in the joiner process.

Portal: <https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/AllUsers>

```powershell
# Sample only - review before running.
Connect-MgGraph -Scopes 'User.ReadWrite.All'
Update-MgUser -UserId '<user>' -Department '<department>'
Set-MgUserManagerByRef -UserId '<user>' -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/users/<manager id>' }
```

## References

- [Add or update a user's profile information](https://learn.microsoft.com/en-us/entra/fundamentals/how-to-manage-user-profile-info)
- [List manager](https://learn.microsoft.com/en-us/graph/api/user-list-manager)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
