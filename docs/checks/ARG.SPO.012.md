# ARG.SPO.012 — OneDrive of deleted or disabled users with content

| | |
|---|---|
| Area | SharePoint |
| Category | Lifecycle |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `Organization.Read.All`, `Reports.Read.All`, `ReportSettings.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader, Reports Reader |
| Licences | — |
| Data sets | OneDriveUsage, ReportSettings, Users, Organization |
| Uses Graph beta | No |
| Tags | OneDrive, Lifecycle, Reports |

## What is checked

OneDrive accounts from the OneDrive usage report (`getOneDriveUsageAccountDetail`, period D180) that still hold content (`Storage Used (Byte)` > 0, not deleted) while their owner is disabled or no longer exists in Microsoft Entra ID. The OneDrive of a deleted user is kept for the retention period set in the SharePoint admin center (30 days by default) and then deleted. With concealed report names, or when the report returns no rows, the result is Investigate. When the report leaves `Site URL` empty (a known issue of the usage reports; this report has no Site Id), the URL comes from the `mySite` property of the user, or is derived from the UPN with the OneDrive naming convention when the user no longer exists (`UrlSource` column).

## Why it matters

Files of people who left stay in OneDrives that nobody looks after, with their sharing links still active. Deciding what to keep and transferring it to a manager or a site is part of the leaver process.

## How to fix

1. For each account, ask the manager whether content must be kept.
2. Transfer the needed files to the manager or to a SharePoint site (the manager gets access automatically when the user is deleted, if configured).
3. Delete the account or let the OneDrive retention period expire; apply a retention policy first when legal requirements apply.

Portal: <https://admin.microsoft.com/sharepoint?page=settings&modern=true>

## References

- [OneDrive retention and deletion](https://learn.microsoft.com/en-us/sharepoint/retention-and-deletion)
- [Microsoft 365 reports in the admin center - OneDrive usage](https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/onedrive-for-business-usage-ww)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
