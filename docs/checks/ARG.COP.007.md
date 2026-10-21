# ARG.COP.007 — Copilot enhanced personalization (memory) is a deliberate choice

| | |
|---|---|
| Area | Copilot |
| Category | AI data processing |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `PeopleSettings.Read.All` |
| Directory roles (delegated) | Global Administrator |
| Licences | — |
| Data sets | CopilotPersonalization |
| Uses Graph beta | Yes |
| Tags | Copilot, AI, GDPR, Privacy |

## What is checked

Reads the enhanced personalization control (`GET /beta/copilot/settings/people/enhancedpersonalization`). When `isEnabledInOrganization` is true and no `disabledForGroup` is set, Copilot memory and personalized recommendations are on for everybody: To review. Passed when the control is off, or on with a group excluded.

## Why it matters

Enhanced personalization lets Copilot use each user's Teams chats, emails, meeting transcripts, usage signals and profile to remember preferences across conversations. The data stays within the user's scope, but it is a new processing purpose that privacy notices and works-council agreements may need to cover.

## How to fix

1. Decide with privacy and HR whether Copilot memory is allowed for everyone, nobody, or everyone except a group.
2. To turn it off for a group, set disabledForGroup to that group's object ID; to turn it off for the organisation, set isEnabledInOrganization to false (PowerShell below).
3. Update the privacy notice for Copilot users accordingly.

Portal: <https://admin.microsoft.com/>

```powershell
# Sample only - review before running.
Connect-MgGraph -Scopes 'PeopleSettings.ReadWrite.All'
Invoke-MgGraphRequest -Method PATCH -Uri 'https://graph.microsoft.com/beta/copilot/settings/people/enhancedpersonalization' -Body @{ disabledForGroup = '<group-object-id>' }
```

## References

- [Microsoft Copilot enhanced personalization control](https://learn.microsoft.com/en-us/graph/control-enhanced-personalization-privacy)
- [Get enhancedPersonalizationSetting](https://learn.microsoft.com/en-us/graph/api/enhancedpersonalizationsetting-get?view=graph-rest-beta)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
