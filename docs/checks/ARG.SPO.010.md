# ARG.SPO.010 — Sites near their storage quota (more than 90%)

| | |
|---|---|
| Area | SharePoint |
| Category | Storage |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `Reports.Read.All`, `ReportSettings.Read.All`, `Sites.Read.All` |
| Directory roles (delegated) | Global Reader, Reports Reader, SharePoint Administrator |
| Licences | — |
| Data sets | SharePointSiteUsage, ReportSettings (optional: SharePointSites) |
| Uses Graph beta | No |
| Tags | SharePoint, Storage, Reports |

## What is checked

SharePoint sites whose used storage is more than **90%** of the allocated storage, from the site usage report (`Storage Used (Byte)` / `Storage Allocated (Byte)`, period D180). Deleted sites and sites without an allocation are ignored. With concealed report names, or when the report returns no rows, the result is Investigate. When the report leaves `Site URL` empty (a known issue of the usage reports), the URL is read from the `Site Id`: first from the PnP tenant site list when SharePoint is connected (it includes private group and channel sites), then with `GET /sites/<id>`, which in delegated mode only reads the sites the account can access.

## Why it matters

A site that reaches its quota becomes read-only for new content, which interrupts work. Planning quota increases or clean-up in advance avoids that.

## How to fix

1. Review large libraries, old versions and the recycle bin of each site.
2. Clean up or archive content that is no longer needed, or reduce the number of kept versions.
3. Increase the site storage limit if the content is needed and tenant storage allows it.

Portal: <https://admin.microsoft.com/sharepoint?page=siteManagement&modern=true>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.SPO.010".Parameters`.

| Name | Default |
|---|---|
| `QuotaPercent` | 90 |

## References

- [Manage site storage limits](https://learn.microsoft.com/en-us/sharepoint/manage-site-collection-storage-limits)
- [Microsoft 365 reports in the admin center - SharePoint site usage](https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/sharepoint-site-usage-ww)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
