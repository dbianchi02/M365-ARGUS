# ARG.ENT.012 — LinkedIn account connections disabled

| | |
|---|---|
| Area | EntraID |
| Category | User settings |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | — |
| Directory roles (delegated) | — |
| Licences | — |
| Data sets | — |
| Uses Graph beta | No |
| Tags | User settings, Manual |

## What is checked

The LinkedIn account connections setting (Microsoft Entra admin center > Users > User settings) lets users connect their work account to LinkedIn in Microsoft apps. It is enabled by default, except for organisations provisioned in Germany or France. Microsoft Graph has no documented API to read this setting, so ARGUS cannot evaluate it: the result is always Investigate and the setting must be checked manually. Expected value: **No** (or Selected group, if a business need was approved).

## Why it matters

Once a user consents, Microsoft apps exchange profile and connection data between the work account and LinkedIn. Whether to allow it is an organisation decision about data sharing with a third-party service, and it should be explicit rather than left at the default.

## How to fix

1. Open the Microsoft Entra admin center > Users > User settings.
2. Under LinkedIn account connections, check the current value.
3. Select No, or Selected group with a group of approved users, and save.
4. Record the decision; ARGUS will keep reporting this check as Investigate because the value cannot be read.

Portal: <https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings>

## References

- [Admin consent for LinkedIn account connections](https://learn.microsoft.com/en-us/entra/identity/users/linkedin-integration)
- [LinkedIn account connections data sharing and consent](https://learn.microsoft.com/en-us/entra/identity/users/linkedin-user-consent)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
