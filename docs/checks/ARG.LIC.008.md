# ARG.LIC.008 — Paid licences assigned directly to users

| | |
|---|---|
| Area | Licensing |
| Category | Licence management |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `LicenseAssignment.Read.All`, `Organization.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | Users, SubscribedSkus, Subscriptions |
| Uses Graph beta | No |
| Tags | Licensing, Groups |

## What is checked

Users with at least one paid licence assigned directly (`licenseAssignmentStates` entry without `assignedByGroup`) instead of through group-based licensing. Free, viral and developer SKUs (the IgnoredSkus list), SKUs with **10,000** or more seats and trial SKUs (`isTrial` in `/directory/subscriptions`) are not counted: they are usually self-service sign-ups. AlsoFromGroup lists the direct licences the user also receives from a group, where the direct assignment is redundant.

## Why it matters

Direct assignments are not driven by group membership: they are not removed when a person changes role or leaves, and they are hard to audit at scale. Group-based licensing keeps paid licences consistent with joiner/mover/leaver processes.

## How to fix

1. Create (or reuse) a security group per licence profile and assign the licences to the group.
2. Add the users to the group and wait for the group assignment to be active.
3. Remove the direct assignments, starting with the redundant ones listed in AlsoFromGroup.

Portal: <https://entra.microsoft.com/#view/Microsoft_AAD_IAM/LicensesMenuBlade/~/Products>

```powershell
# Sample only - review before running. Removes one directly assigned licence after the group assignment is active.
Connect-MgGraph -Scopes 'User.ReadWrite.All'
Set-MgUserLicense -UserId '<ObjectId>' -AddLicenses @() -RemoveLicenses @('<SkuId>')
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.LIC.008".Parameters`.

| Name | Default |
|---|---|
| `FreeSeatThreshold` | 10000 |
| `IgnoredSkus` | FLOW_FREE, POWER_BI_STANDARD, POWER_BI_STANDARD_FACULTY, POWER_BI_STANDARD_STUDENT, POWER_BI_INDIVIDUAL_USER, TEAMS_EXPLORATORY, Microsoft_Teams_Exploratory_Dept, TEAMS_FREE, TEAMS_COMMERCIAL_TRIAL, MS_TEAMS_IW, POWERAPPS_VIRAL, POWERAPPS_DEV, POWERAPPS_INDIVIDUAL_USER, CCIBOTS_PRIVPREV_VIRAL, Power_Pages_vTrial_for_Makers, DYN365_CUSTOMER_INSIGHTS_VIRAL, Dynamics_365_Customer_Service_Enterprise_viral_trial, Dynamics_365_Field_Service_Enterprise_viral_trial, Dynamics_365_Sales_Premium_Viral_Trial, Dynamics_365_Guides_vTrial, Microsoft_Cloud_for_Sustainability_vTrial, FORMS_PRO, WINDOWS_STORE, RIGHTSMANAGEMENT_ADHOC, STREAM, MCOPSTNC, MICROSOFT_BUSINESS_CENTER, SMB_APPS, DEVELOPERPACK, DEVELOPERPACK_E5 |

## References

- [What is group-based licensing in Microsoft Entra ID?](https://learn.microsoft.com/en-us/entra/fundamentals/concept-group-based-licensing)
- [Migrate users from individual licenses to group-based licenses](https://learn.microsoft.com/en-us/entra/identity/users/licensing-groups-migrate-users)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
