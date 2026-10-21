# ARG.LIC.004 — Users with overlapping licences

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
| Tags | Licensing, Cost |

## What is checked

Users with two paid SKUs where every service plan of one SKU is also in the other (from `subscribedSkus.servicePlans`), typically a standalone product or an older suite next to the suite that includes it. The contained SKU is redundant. The comparison uses service plan IDs, so it needs no list of SKU names; free, viral and trial SKUs are ignored as in ARG.LIC.006.

## Why it matters

Overlapping licences usually come from upgrades where the old SKU was never removed, or from two licensing groups that both include the user. The contained seat is paid twice and blocks a seat that could go to someone else.

## How to fix

1. For each user, confirm that the larger SKU covers what the user needs.
2. Remove the redundant SKU, or the user from the licensing group that assigns it.
3. After upgrades, reduce the quantity of the old SKU at renewal.

Portal: <https://admin.microsoft.com/#/licenses>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.LIC.004".Parameters`.

| Name | Default |
|---|---|
| `FreeSeatThreshold` | 10000 |
| `IgnoredSkus` | FLOW_FREE, POWER_BI_STANDARD, POWER_BI_STANDARD_FACULTY, POWER_BI_STANDARD_STUDENT, POWER_BI_INDIVIDUAL_USER, TEAMS_EXPLORATORY, Microsoft_Teams_Exploratory_Dept, TEAMS_FREE, TEAMS_COMMERCIAL_TRIAL, MS_TEAMS_IW, POWERAPPS_VIRAL, POWERAPPS_DEV, POWERAPPS_INDIVIDUAL_USER, CCIBOTS_PRIVPREV_VIRAL, Power_Pages_vTrial_for_Makers, DYN365_CUSTOMER_INSIGHTS_VIRAL, Dynamics_365_Customer_Service_Enterprise_viral_trial, Dynamics_365_Field_Service_Enterprise_viral_trial, Dynamics_365_Sales_Premium_Viral_Trial, Dynamics_365_Guides_vTrial, Microsoft_Cloud_for_Sustainability_vTrial, FORMS_PRO, WINDOWS_STORE, RIGHTSMANAGEMENT_ADHOC, STREAM, MCOPSTNC, MICROSOFT_BUSINESS_CENTER, SMB_APPS, DEVELOPERPACK, DEVELOPERPACK_E5 |

## References

- [Product names and service plan identifiers for licensing](https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference)
- [subscribedSku resource type](https://learn.microsoft.com/en-us/graph/api/resources/subscribedsku)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
