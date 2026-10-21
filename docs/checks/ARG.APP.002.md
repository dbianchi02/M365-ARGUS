# ARG.APP.002 — Client secrets expiring within 30 days

| | |
|---|---|
| Area | Applications |
| Category | Credential hygiene |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `Application.Read.All` |
| Directory roles (delegated) | Application Administrator, Global Reader |
| Licences | — |
| Data sets | Applications |
| Uses Graph beta | No |
| Tags | Applications, Credentials |

## What is checked

Client secrets (`passwordCredentials`) of app registrations that expire within the next **30** days. A secret counts as **replaced** when the same app already has another secret valid beyond that window; the check fails only for secrets without a replacement.

## Why it matters

An expired secret stops the integration that uses it. Planned rotation, owned by someone, avoids outages discovered by users.

## How to fix

1. Ask the application owner which service uses the secret.
2. Add a new secret (or, better, a certificate or managed identity), update the service, and test it.
3. Delete the old secret once nothing uses it.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running. Removes an old secret after the service was updated.
Connect-MgGraph -Scopes 'Application.ReadWrite.All'
Remove-MgApplicationPassword -ApplicationId '<ObjectId>' -KeyId '<KeyId>'
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.APP.002".Parameters`.

| Name | Default |
|---|---|
| `DaysAhead` | 30 |

## References

- [Add and manage app credentials in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials)
- [Security best practices for application properties](https://learn.microsoft.com/en-us/entra/identity-platform/security-best-practices-for-app-registration)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
