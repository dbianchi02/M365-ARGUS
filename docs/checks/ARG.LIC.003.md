# ARG.LIC.003 — Paid licences assigned to guest users

| | |
|---|---|
| Area | Licensing |
| Category | Licence hygiene |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `LicenseAssignment.Read.All`, `Organization.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | Users, SubscribedSkus, Subscriptions |
| Uses Graph beta | No |
| Tags | Licensing, Guests, Cost |

## What is checked

Guest users (`userType` = Guest) with at least one paid licence. Free, viral and trial SKUs are ignored (`IgnoredSkus`, trial subscriptions from `/directory/subscriptions`), as in ARG.LIC.006. Guests normally work with the licences of their home organisation or with the B2B allowance; a paid seat on a guest is usually a mistake or a leftover.

## Why it matters

Licences assigned to guests cost a full seat, are rarely reviewed and often stay after the collaboration ends. When a guest really needs a licence, it should be a documented decision with a sponsor, not the side effect of a group-based assignment.

## How to fix

1. Check why each guest has the licence (direct assignment or a licensing group that includes guests).
2. Remove the licence, or exclude guests from the licensing group (for example with a dynamic group rule on userType).
3. When a guest needs a licence on purpose, record the decision and the sponsor.

Portal: <https://admin.microsoft.com/#/licenses>

```powershell
# Sample only - review before running.
Connect-MgGraph -Scopes 'User.ReadWrite.All'
Set-MgUserLicense -UserId '<guest id>' -AddLicenses @() -RemoveLicenses @('<skuId>')
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.LIC.003".Parameters`.

| Name | Default |
|---|---|
| `FreeSeatThreshold` | 10000 |
| `IgnoredSkus` | FLOW_FREE, POWER_BI_STANDARD, POWER_BI_STANDARD_FACULTY, POWER_BI_STANDARD_STUDENT, POWER_BI_INDIVIDUAL_USER, TEAMS_EXPLORATORY, Microsoft_Teams_Exploratory_Dept, TEAMS_FREE, TEAMS_COMMERCIAL_TRIAL, MS_TEAMS_IW, POWERAPPS_VIRAL, POWERAPPS_DEV, POWERAPPS_INDIVIDUAL_USER, CCIBOTS_PRIVPREV_VIRAL, Power_Pages_vTrial_for_Makers, DYN365_CUSTOMER_INSIGHTS_VIRAL, Dynamics_365_Customer_Service_Enterprise_viral_trial, Dynamics_365_Field_Service_Enterprise_viral_trial, Dynamics_365_Sales_Premium_Viral_Trial, Dynamics_365_Guides_vTrial, Microsoft_Cloud_for_Sustainability_vTrial, FORMS_PRO, WINDOWS_STORE, RIGHTSMANAGEMENT_ADHOC, STREAM, MCOPSTNC, MICROSOFT_BUSINESS_CENTER, SMB_APPS, DEVELOPERPACK, DEVELOPERPACK_E5 |

## References

- [Microsoft Entra External ID B2B licensing](https://learn.microsoft.com/en-us/entra/external-id/external-identities-pricing)
- [Assign or remove licenses for user accounts](https://learn.microsoft.com/en-us/entra/fundamentals/license-users-groups)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
