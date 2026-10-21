# ARG.LIC.005 — Licence assignment errors

| | |
|---|---|
| Area | Licensing |
| Category | Licence hygiene |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `Group.Read.All`, `LicenseAssignment.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | Users, SubscribedSkus (optional: Groups) |
| Uses Graph beta | No |
| Tags | Licensing |

## What is checked

Users whose `licenseAssignmentStates` contain an entry in state **Error** (the licence is not assigned) or **ActiveWithError** (assigned, but part of it failed). The error column shows the reason reported by Microsoft Entra ID, for example CountViolation (not enough seats), MutuallyExclusiveViolation or ProhibitedInUsageLocationViolation. Group names are shown when groups could be read.

## Why it matters

Assignment errors leave users without the services they are expected to have, and usually go unnoticed when licences are assigned through groups.

## How to fix

1. Open the group (for group-based licensing) or the user in the Microsoft Entra admin center and read the error.
2. Fix the cause: buy or free seats (CountViolation), remove the conflicting licence (MutuallyExclusiveViolation), add the missing prerequisite licence (DependencyViolation), or set the usage location.
3. Reprocess the group or user so the assignment is retried.

Portal: <https://entra.microsoft.com/#view/Microsoft_AAD_IAM/LicensesMenuBlade/~/Products>

## References

- [Identify and resolve license assignment problems for a group](https://learn.microsoft.com/en-us/entra/identity/users/licensing-groups-resolve-problems)
- [licenseAssignmentState resource type](https://learn.microsoft.com/en-us/graph/api/resources/licenseassignmentstate)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
