# ARG.APP.006 — Expired certificates still present

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

Certificates (`keyCredentials`, any usage) whose `endDateTime` is in the past but that are still attached to the app registration.

## Why it matters

Expired certificates are clutter that hides which credentials are really in use and makes credential reviews harder.

## How to fix

1. Confirm the expired certificate is no longer deployed anywhere.
2. Delete it from the app registration (Certificates & secrets > Certificates).

Portal: <https://entra.microsoft.com/>

## References

- [Add and manage app credentials in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
