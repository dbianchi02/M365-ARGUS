# ARG.APP.007 — Certificates with a lifetime above 180 days

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

Valid authentication certificates (`keyCredentials` with usage **Verify**) whose lifetime (`endDateTime` minus `startDateTime`) exceeds **180** days. Expired certificates are covered by ARG.APP.006.

## Why it matters

Microsoft recommends limiting application certificate lifetime to 180 days and automating renewal. Long-lived certificates are rarely rotated and stay valid long after the people who deployed them have moved on.

## How to fix

1. Issue certificates from Azure Key Vault with automatic renewal and a lifetime within the policy (Microsoft recommends 180 days or less).
2. Upload the new certificate, deploy it to the service, then remove the long-lived one.
3. Consider an application management policy that limits certificate lifetime (asymmetricKeyLifetime) for new credentials.

Portal: <https://entra.microsoft.com/>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.APP.007".Parameters`.

| Name | Default |
|---|---|
| `MaxLifetimeDays` | 180 |

## References

- [Enforce secret and certificate standards with application management policies](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/tutorial-enforce-secret-standards)
- [Add and manage app credentials in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
