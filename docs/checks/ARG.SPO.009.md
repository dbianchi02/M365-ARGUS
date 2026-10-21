# ARG.SPO.009 — Inactive SharePoint sites (more than 180 days)

| | |
|---|---|
| Area | SharePoint |
| Category | Lifecycle |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `Reports.Read.All`, `ReportSettings.Read.All`, `Sites.Read.All` |
| Directory roles (delegated) | Global Reader, Reports Reader, SharePoint Administrator |
| Licences | — |
| Data sets | SharePointSiteUsage, ReportSettings (optional: SharePointSites) |
| Uses Graph beta | No |
| Tags | SharePoint, Lifecycle, Reports |

## What is checked

SharePoint sites whose `Last Activity Date` in the site usage report (`getSharePointSiteUsageDetail`, period D180) is older than **180** days or empty (no activity in the report period). Deleted sites and system sites (`ExcludedTemplates`: search center, compliance policy center, tenant fundamental site, app catalog) are ignored; OneDrive accounts are not part of this report. When the report leaves `Site URL` empty (a known issue of the usage reports), the URL is read from the `Site Id`: first from the PnP tenant site list when SharePoint is connected (it includes private group and channel sites), then with `GET /sites/<id>`, which in delegated mode only reads the sites the account can access; the owner falls back to `Owner Display Name` and is "Not reported" when the report has none. With concealed report names, or when the report returns no rows, the result is Investigate.

## Why it matters

Inactive sites hold content and permissions that nobody curates, use storage and appear in search. Reviewing them regularly keeps the information architecture clean.

## How to fix

1. Contact the site owners and confirm whether each site is still needed.
2. Archive (Microsoft 365 Archive) or set to read-only the sites whose content must be kept, delete the others after your retention period.
3. Consider a site lifecycle policy for inactive sites (SharePoint Advanced Management).

Portal: <https://admin.microsoft.com/sharepoint?page=siteManagement&modern=true>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.SPO.009".Parameters`.

| Name | Default |
|---|---|
| `ExcludedTemplates` | Basic Search Center, Enterprise Search Center, Compliance Policy Center, SharePoint Online Tenant Fundamental Site, App Catalog Site, Tenant Admin Site |
| `InactiveDays` | 180 |

## References

- [Microsoft 365 reports in the admin center - SharePoint site usage](https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/sharepoint-site-usage-ww)
- [Manage site lifecycle policies](https://learn.microsoft.com/en-us/sharepoint/site-lifecycle-management)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
