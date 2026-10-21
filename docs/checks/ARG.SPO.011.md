# ARG.SPO.011 — OneDrive retention for deleted users is at least 90 days

| | |
|---|---|
| Area | SharePoint |
| Category | Lifecycle |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `SharePointTenantSettings.Read.All` |
| Directory roles (delegated) | Global Reader, SharePoint Administrator |
| Licences | — |
| Data sets | SharePointTenantSettings |
| Uses Graph beta | No |
| Tags | OneDrive, Lifecycle, Policy |

## What is checked

Reads `admin/sharepoint/settings.deletedUserPersonalSiteRetentionPeriodInDays`: how long the OneDrive of a deleted user is kept before it is deleted (30 days by default, up to 3650). Fails when it is shorter than **90** days.

## Why it matters

After a user is deleted, the manager has only this period to find and move business files from the OneDrive. Thirty days is often shorter than the time it takes to notice that something is missing, especially when the leaver process runs late.

## How to fix

1. Agree the retention period with records management (for example 90 or 365 days).
2. In the SharePoint admin center, go to Settings > OneDrive retention and set Days to retain a deleted user's OneDrive.
3. Make sure the leaver process grants the manager access to the OneDrive and that retention policies cover legal requirements.

Portal: <https://admin.microsoft.com/sharepoint?page=settings&modern=true>

```powershell
# Sample only - review before running.
Connect-MgGraph -Scopes 'SharePointTenantSettings.ReadWrite.All'
Invoke-MgGraphRequest -Method PATCH -Uri 'https://graph.microsoft.com/v1.0/admin/sharepoint/settings' -Body @{ deletedUserPersonalSiteRetentionPeriodInDays = 365 }
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.SPO.011".Parameters`.

| Name | Default |
|---|---|
| `MinRetentionDays` | 90 |

## References

- [Set the OneDrive retention for deleted users](https://learn.microsoft.com/en-us/sharepoint/set-retention)
- [OneDrive retention and deletion](https://learn.microsoft.com/en-us/sharepoint/retention-and-deletion)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
