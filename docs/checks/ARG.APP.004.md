# ARG.APP.004 — Client secrets with a lifetime above 24 months

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

Valid client secrets whose lifetime (`endDateTime` minus `startDateTime`) exceeds **24** months. The admin center limits new secrets to 24 months, but secrets created through the API or before that limit can last much longer. Expired secrets are covered by ARG.APP.003.

## Why it matters

Long-lived secrets are rarely rotated and outlive the people and documentation that explain them. Microsoft recommends less than 12 months, or certificates and managed identities instead.

## How to fix

1. Replace the secret with a certificate or a managed identity where possible; otherwise create a secret with a shorter lifetime.
2. Update the service that uses it, then delete the long-lived secret.
3. Consider an application management policy that limits secret lifetime for new credentials.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running. Adds a 6-month secret; store the returned value securely.
Connect-MgGraph -Scopes 'Application.ReadWrite.All'
Add-MgApplicationPassword -ApplicationId '<ObjectId>' -PasswordCredential @{ DisplayName = 'rotated'; EndDateTime = (Get-Date).AddMonths(6) }
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.APP.004".Parameters`.

| Name | Default |
|---|---|
| `MaxLifetimeMonths` | 24 |

## References

- [Add and manage app credentials in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials)
- [Enforce secret and certificate standards with application management policies](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/tutorial-enforce-secret-standards)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
