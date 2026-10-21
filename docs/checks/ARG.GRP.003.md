# ARG.GRP.003 — Group expiration policy configured

| | |
|---|---|
| Area | GroupsTeams |
| Category | Lifecycle |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `Directory.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | GroupLifecyclePolicies |
| Uses Graph beta | No |
| Tags | Groups, Lifecycle |

## What is checked

Reads `groupLifecyclePolicies`. Fails when no expiration policy exists or when it applies to no group (`managedGroupTypes` = None); a policy that applies only to selected groups is Investigate. Groups with recent activity are renewed automatically, so active owners are not disturbed.

## Why it matters

Without an expiration policy, Microsoft 365 groups and Teams that are no longer used stay forever with their content, guests and permissions. Expiration asks owners to confirm that the group is still needed.

## How to fix

1. In the Microsoft Entra admin center open Groups > Expiration.
2. Set a lifetime (for example 365 days), an e-mail address for ownerless groups, and apply it to All groups.
3. Make sure groups have owners first (ARG.GRP.004), otherwise expiry notices only go to the fallback address.

Portal: <https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/Lifecycle>

## References

- [Microsoft 365 group expiration policy](https://learn.microsoft.com/en-us/microsoft-365/solutions/microsoft-365-groups-expiration-policy)
- [Configure the expiration policy for Microsoft 365 groups](https://learn.microsoft.com/en-us/entra/identity/users/groups-lifecycle)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
