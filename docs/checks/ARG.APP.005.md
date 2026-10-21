# ARG.APP.005 — Certificates expiring within 30 days

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

Certificates (`keyCredentials` with usage **Verify**, used by the app to authenticate) that expire within the next **30** days. A certificate counts as **replaced** when the same app already has another certificate valid beyond that window; the check fails only for certificates without a replacement.

## Why it matters

An expired certificate stops app-only integrations (automation, connectors, scripts). Planned renewal avoids outages.

## How to fix

1. Ask the application owner which service uses the certificate.
2. Issue a new certificate (ideally from Azure Key Vault with automatic renewal), upload it to the app registration and deploy it to the service.
3. Remove the old certificate once nothing uses it.

Portal: <https://entra.microsoft.com/>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.APP.005".Parameters`.

| Name | Default |
|---|---|
| `DaysAhead` | 30 |

## References

- [Add and manage app credentials in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials)
- [Enforce secret and certificate standards with application management policies](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/tutorial-enforce-secret-standards)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
