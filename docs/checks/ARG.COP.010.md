# ARG.COP.010 — Org-wide agent sharing is restricted (manual review)

| | |
|---|---|
| Area | Copilot |
| Category | Agent governance |
| Severity | Info |
| Services | Graph |
| Graph permissions (read-only) | — |
| Directory roles (delegated) | — |
| Licences | — |
| Data sets | — |
| Uses Graph beta | No |
| Tags | Copilot, Agents, Sharing, Manual |

## What is checked

The Sharing setting (Microsoft 365 admin center > Agents > Settings > Sharing) decides who can share agents built with Copilot Agent Builder (Copilot Studio lite) with the whole organisation: All users (default), No users, or Specific users. Sharing with named people stays possible in every case. No Microsoft API exposes the setting, so this check is always To review. Info severity: it does not change the score.

## Why it matters

An agent shared with everyone answers from the knowledge sources its creator chose, for every user who opens it. Restricting org-wide sharing to a few publishers keeps the agent catalogue curated and avoids duplicate or unreviewed agents reaching the whole company.

## How to fix

1. In the Microsoft 365 admin center, go to Agents > Settings > Sharing.
2. Choose No users or Specific users (a group of approved publishers) instead of All users.
3. Review agents already shared with the whole organisation on the Agents page and block or reassign the ones without an owner.

Portal: <https://admin.microsoft.com/>

## References

- [Agent settings in Microsoft 365 admin center: Sharing](https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-settings)
- [Share and manage agents built with Microsoft 365 Copilot](https://learn.microsoft.com/en-us/microsoft-365-copilot/extensibility/copilot-studio-lite-publish-agent)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
