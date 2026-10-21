# ARG.ENT.010 — Users can register applications

| | |
|---|---|
| Area | EntraID |
| Category | Application governance |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `Policy.Read.All` |
| Directory roles (delegated) | Global Reader |
| Licences | — |
| Data sets | AuthorizationPolicy |
| Uses Graph beta | No |
| Tags | Applications, Policy |

## What is checked

Reads `authorizationPolicy.defaultUserRolePermissions.allowedToCreateApps` ("Users can register applications" in User settings). Fails when every user can create app registrations.

## Why it matters

App registrations created by anyone end up without an owner, a purpose or a credential policy. Restricting creation to the Application Developer role keeps the application estate governable.

## How to fix

1. In the Microsoft Entra admin center, go to Users > User settings.
2. Set 'Users can register applications' to No.
3. Assign the Application Developer role to the people who need to register applications.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running.
Connect-MgGraph -Scopes 'Policy.ReadWrite.Authorization'
Update-MgPolicyAuthorizationPolicy -DefaultUserRolePermissions @{ AllowedToCreateApps = $false }
```

## References

- [Delegate application management permissions](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/delegate-app-roles)
- [Default user permissions](https://learn.microsoft.com/en-us/entra/fundamentals/users-default-permissions)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
