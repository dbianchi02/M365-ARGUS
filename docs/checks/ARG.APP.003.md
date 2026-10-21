# ARG.APP.003 — Expired client secrets still present

| | |
|---|---|
| Area | Applications |
| Category | Credential hygiene |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `Application.Read.All` |
| Directory roles (delegated) | Application Administrator, Global Reader |
| Licences | — |
| Data sets | Applications |
| Uses Graph beta | No |
| Tags | Applications, Credentials |

## What is checked

Client secrets (`passwordCredentials`) whose `endDateTime` is in the past but that are still attached to the app registration.

## Why it matters

Expired secrets are clutter that hides which credentials are really in use and makes credential reviews harder.

## How to fix

1. Confirm the expired secret is not referenced in any documentation or runbook as current.
2. Delete the expired secret from the app registration (Certificates & secrets).

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running.
Connect-MgGraph -Scopes 'Application.ReadWrite.All'
Remove-MgApplicationPassword -ApplicationId '<ObjectId>' -KeyId '<KeyId>'
```

## References

- [Add and manage app credentials in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
