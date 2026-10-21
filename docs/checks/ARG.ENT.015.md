# ARG.ENT.015 — Directory synchronisation is up to date

| | |
|---|---|
| Area | EntraID |
| Category | Hybrid identity |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `Organization.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | Organization |
| Uses Graph beta | No |
| Tags | Hybrid, Lifecycle |

## What is checked

For hybrid tenants (`organization.onPremisesSyncEnabled` = true), fails when the last directory synchronisation (`onPremisesLastSyncDateTime`) is older than **24** hours. Cloud-only tenants are skipped.

## Why it matters

When synchronisation stops, changes made on-premises (leavers disabled, group changes) no longer reach Microsoft 365, and governance decisions are based on stale data.

## How to fix

1. Check the Microsoft Entra Connect (or Cloud Sync) server and its service.
2. Review synchronisation errors in Microsoft Entra Connect Health.
3. If synchronisation was decommissioned on purpose, turn it off in the tenant so the state is explicit.

Portal: <https://entra.microsoft.com/>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.ENT.015".Parameters`.

| Name | Default |
|---|---|
| `MaxSyncAgeHours` | 24 |

## References

- [Using Microsoft Entra Connect Health with sync](https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-health-sync)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
