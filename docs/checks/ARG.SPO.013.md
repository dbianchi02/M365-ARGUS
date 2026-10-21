# ARG.SPO.013 — OneDrives near their storage quota (more than 90%)

| | |
|---|---|
| Area | SharePoint |
| Category | Storage |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `Organization.Read.All`, `Reports.Read.All`, `ReportSettings.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader, Reports Reader |
| Licences | — |
| Data sets | OneDriveUsage, ReportSettings, Users, Organization |
| Uses Graph beta | No |
| Tags | OneDrive, Storage, Reports |

## What is checked

OneDrive accounts from the OneDrive usage report (`getOneDriveUsageAccountDetail`, period D180) whose `Storage Used (Byte)` is more than **90%** of `Storage Allocated (Byte)`. Deleted accounts and accounts without an allocation are ignored. With concealed report names, or when the report returns no rows, the result is Investigate. When the report leaves `Site URL` empty (a known issue of the usage reports; this report has no Site Id), the URL comes from the `mySite` property of the user, or is derived from the UPN with the OneDrive naming convention when the user no longer exists (`UrlSource` column).

## Why it matters

A full OneDrive stops syncing and saving, and users start keeping files on local disks or personal storage. Accounts close to the limit need a cleanup, a move of team content to SharePoint, or a higher quota.

## How to fix

1. Ask the users to move team content to the relevant SharePoint sites and remove duplicates.
2. Raise the OneDrive quota for users who need it (SharePoint admin center > Settings > OneDrive storage limit, or per user).
3. Review the default OneDrive storage limit for new users.

Portal: <https://admin.microsoft.com/sharepoint?page=settings&modern=true>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.SPO.013".Parameters`.

| Name | Default |
|---|---|
| `QuotaPercent` | 90 |

## References

- [Set the default storage space for OneDrive users](https://learn.microsoft.com/en-us/sharepoint/set-default-storage-space)
- [Microsoft 365 reports in the admin center - OneDrive usage](https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/onedrive-for-business-usage-ww)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
