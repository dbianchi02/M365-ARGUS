# ARG.EXO.008 — User mailboxes without a mailbox hold (informational)

| | |
|---|---|
| Area | Exchange |
| Category | Retention governance |
| Severity | Info |
| Services | Graph, Exchange |
| Graph permissions (read-only) | — |
| Directory roles (delegated) | Global Reader, View-Only Organization Management |
| Exchange Online | Entra role Global Reader, or Exchange role group View-Only Organization Management |
| Licences | — |
| Data sets | Mailboxes |
| Uses Graph beta | No |
| Tags | Exchange, Mailboxes, Retention, Inventory |

## What is checked

Counts user mailboxes with Litigation Hold (`LitigationHoldEnabled`) or an in-place, eDiscovery or retention hold listed in `InPlaceHolds`, and lists the ones with neither. Organisation-wide Microsoft Purview retention policies are not visible to ARGUS (they need the Security & Compliance PowerShell), so a mailbox without a mailbox hold may still be retained: this check is always To review when such mailboxes exist. Info severity: it does not change the score.

## Why it matters

Whether mail must be preserved, for how long and for whom, is a records-management decision. Holds set mailbox by mailbox drift over time; knowing which mailboxes have one, and confirming that a retention policy covers the others, keeps the retention strategy consistent with legal requirements.

## How to fix

1. In the Microsoft Purview portal, check the retention policies that include Exchange mailboxes (Data lifecycle management > Policies > Retention policies).
2. If an organisation-wide policy covers all mailboxes, no mailbox hold is needed; document it.
3. Otherwise, apply a retention policy or Litigation Hold to the mailboxes that must be preserved.

Portal: <https://purview.microsoft.com/datalifecyclemanagement/retention>

## References

- [Learn about retention policies and retention labels](https://learn.microsoft.com/en-us/purview/retention)
- [Place a mailbox on Litigation Hold](https://learn.microsoft.com/en-us/purview/ediscovery-create-a-litigation-hold)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
