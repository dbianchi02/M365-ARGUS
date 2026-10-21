# ARG.GRP.002 — Group naming policy configured

| | |
|---|---|
| Area | GroupsTeams |
| Category | Group governance |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `GroupSettings.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | AAD_PREMIUM |
| Data sets | GroupSettings |
| Uses Graph beta | No |
| Tags | Groups, Policy |

## What is checked

Reads `PrefixSuffixNamingRequirement` and `CustomBlockedWordsList` in the tenant-wide Group.Unified directory setting. Passes when a prefix/suffix rule or a blocked-words list is configured. The naming policy requires Microsoft Entra ID P1 for the users it applies to.

## Why it matters

A naming convention (for example a GRP- prefix or a department attribute) makes groups and Teams easy to recognise in the address book, in Teams and in SharePoint; blocked words prevent misleading names.

## How to fix

1. Agree on a naming convention (fixed prefix or suffix, or one based on user attributes such as department).
2. Configure it in the Microsoft Entra admin center: Groups > Naming policy.
3. Optionally add a list of blocked words.

Portal: <https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/NamingPolicy>

## References

- [Microsoft 365 groups naming policy](https://learn.microsoft.com/en-us/microsoft-365/solutions/groups-naming-policy)
- [Enforce a group naming policy in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/users/groups-naming-policy)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
