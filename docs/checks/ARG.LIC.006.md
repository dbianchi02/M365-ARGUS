# ARG.LIC.006 — Unused licences per SKU

| | |
|---|---|
| Area | Licensing |
| Category | Cost |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `LicenseAssignment.Read.All`, `Organization.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | SubscribedSkus, Subscriptions |
| Uses Graph beta | No |
| Tags | Licensing, Cost |

## What is checked

Compares purchased seats (`prepaidUnits.enabled`) with assigned seats (`consumedUnits`) for every active, user-assignable SKU (`capabilityStatus` = Enabled, `appliesTo` = User). A SKU fails when more than **10%** or more than **5** seats are unused. Free, viral and developer SKUs (the IgnoredSkus list), SKUs with **10,000** or more seats (free offers are provisioned with very large quantities) and trial SKUs (`isTrial` in `/directory/subscriptions`) are ignored.

## Why it matters

Unused seats are a recurring cost with no business value. Reviewing them before each renewal is the simplest licence saving.

## How to fix

1. Confirm the unused seats are not reserved for planned hires or a migration.
2. Reassign the seats, or reduce the subscription quantity (for annual commitments, at the next renewal).
3. Review the SKUs regularly, for example monthly.

Portal: <https://admin.microsoft.com/Adminportal/Home#/licenses>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.LIC.006".Parameters`.

| Name | Default |
|---|---|
| `FreeSeatThreshold` | 10000 |
| `IgnoredSkus` | FLOW_FREE, POWER_BI_STANDARD, POWER_BI_STANDARD_FACULTY, POWER_BI_STANDARD_STUDENT, POWER_BI_INDIVIDUAL_USER, TEAMS_EXPLORATORY, Microsoft_Teams_Exploratory_Dept, TEAMS_FREE, TEAMS_COMMERCIAL_TRIAL, MS_TEAMS_IW, POWERAPPS_VIRAL, POWERAPPS_DEV, POWERAPPS_INDIVIDUAL_USER, CCIBOTS_PRIVPREV_VIRAL, Power_Pages_vTrial_for_Makers, DYN365_CUSTOMER_INSIGHTS_VIRAL, Dynamics_365_Customer_Service_Enterprise_viral_trial, Dynamics_365_Field_Service_Enterprise_viral_trial, Dynamics_365_Sales_Premium_Viral_Trial, Dynamics_365_Guides_vTrial, Microsoft_Cloud_for_Sustainability_vTrial, FORMS_PRO, WINDOWS_STORE, RIGHTSMANAGEMENT_ADHOC, STREAM, MCOPSTNC, MICROSOFT_BUSINESS_CENTER, SMB_APPS, DEVELOPERPACK, DEVELOPERPACK_E5 |
| `UnusedPercent` | 10 |
| `UnusedSeats` | 5 |

## References

- [Buy or remove licenses for a Microsoft business subscription](https://learn.microsoft.com/en-us/microsoft-365/commerce/licenses/buy-licenses)
- [Product names and service plan identifiers for licensing](https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
