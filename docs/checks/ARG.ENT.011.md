# ARG.ENT.011 — Users can create tenants

| | |
|---|---|
| Area | EntraID |
| Category | Tenant governance |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `Policy.Read.All` |
| Directory roles (delegated) | Global Reader |
| Licences | — |
| Data sets | AuthorizationPolicy |
| Uses Graph beta | No |
| Tags | Policy, Tenant |

## What is checked

Reads `authorizationPolicy.defaultUserRolePermissions.allowedToCreateTenants` ("Restrict non-admin users from creating tenants" in User settings). Fails when non-admin users can create Microsoft Entra tenants.

## Why it matters

A tenant created by a user becomes a separate directory where that user is Global Administrator, outside the organisation's governance and visibility.

## How to fix

1. In the Microsoft Entra admin center, go to Users > User settings.
2. Set 'Restrict non-admin users from creating tenants' to Yes.
3. Assign the Tenant Creator role to anyone who legitimately needs to create tenants.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running.
Connect-MgGraph -Scopes 'Policy.ReadWrite.Authorization'
Update-MgPolicyAuthorizationPolicy -DefaultUserRolePermissions @{ AllowedToCreateTenants = $false }
```

## References

- [Default user permissions (restrict tenant creation)](https://learn.microsoft.com/en-us/entra/fundamentals/users-default-permissions)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
