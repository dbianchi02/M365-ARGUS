# ARG.APP.001 — App registrations without owners

| | |
|---|---|
| Area | Applications |
| Category | Application governance |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `Application.Read.All` |
| Directory roles (delegated) | Application Administrator, Global Reader |
| Licences | — |
| Data sets | Applications |
| Uses Graph beta | No |
| Tags | Applications, Ownership |

## What is checked

App registrations with no owner. The findings show how many secrets and certificates each app holds: an ownerless app with credentials is the first to review.

## Why it matters

Without an owner nobody is accountable for the app's permissions, credentials and lifecycle, and nobody notices when it is no longer needed.

## How to fix

1. Identify who uses the application (sign-in logs, credentials, API permissions help).
2. Assign at least one owner (two is better) in App registrations > Owners.
3. Delete applications that nobody claims after a grace period.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running. Adds an owner to one app registration.
Connect-MgGraph -Scopes 'Application.ReadWrite.All'
New-MgApplicationOwnerByRef -ApplicationId '<ObjectId>' -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/directoryObjects/<OwnerObjectId>' }
```

## References

- [Security best practices for application properties (app ownership)](https://learn.microsoft.com/en-us/entra/identity-platform/security-best-practices-for-app-registration)
- [Assign enterprise application owners](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/assign-app-owners)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
