# ARG.ENT.014 — Stale devices (no sign-in for more than 180 days)

| | |
|---|---|
| Area | EntraID |
| Category | Device hygiene |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `Device.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | Devices |
| Uses Graph beta | No |
| Tags | Devices, Lifecycle |

## What is checked

Devices whose `approximateLastSignInDateTime` is older than **180** days (or that never signed in and were registered more than 180 days ago). Both enabled and disabled devices are listed; disabled ones are usually ready to be deleted.

## Why it matters

Stale devices make device inventories, Conditional Access reporting and licence counts unreliable.

## How to fix

1. Disable stale devices first and wait a grace period (for example 30 days).
2. Delete devices that nobody claimed.
3. Before deleting Windows devices, make sure BitLocker recovery keys you still need are kept, and do not delete Windows Autopilot devices from Entra ID directly.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running. Disables one device.
Connect-MgGraph -Scopes 'Device.ReadWrite.All'
Update-MgDevice -DeviceId '<Id>' -AccountEnabled:$false
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.ENT.014".Parameters`.

| Name | Default |
|---|---|
| `StaleDays` | 180 |

## References

- [How to manage stale devices in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/devices/manage-stale-devices)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
