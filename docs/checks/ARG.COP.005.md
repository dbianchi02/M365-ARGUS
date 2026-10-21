# ARG.COP.005 — Anthropic models with Data Retention, independent processor (manual review)

| | |
|---|---|
| Area | Copilot |
| Category | AI data processing |
| Severity | Info |
| Services | Graph |
| Graph permissions (read-only) | — |
| Directory roles (delegated) | — |
| Licences | — |
| Data sets | — |
| Uses Graph beta | No |
| Tags | Copilot, AI, GDPR, Manual |

## What is checked

"Anthropic models with Data Retention" (for example some Fable- and Mythos-class models) are offered under Anthropic's own Commercial Terms and Data Processing Addendum: Anthropic acts as an independent processor, outside the Microsoft Product Terms and DPA, and retains inputs and outputs. They are off by default in every region and must be enabled explicitly in the Microsoft 365 admin center. No Microsoft API exposes the setting, so this check is always To review. Info severity: it does not change the score.

## Why it matters

With these models prompts, files and responses are stored by Anthropic (most data up to 30 days, flagged content longer) under terms the organisation signs directly with Anthropic. That is a separate data-processing relationship and, for EU organisations, an international transfer that needs its own legal assessment.

## How to fix

1. In the Microsoft 365 admin center, go to Copilot > Settings > View all and open the Anthropic models with Data Retention setting.
2. Check whether it was enabled and for which users or groups.
3. Keep it off unless legal and the DPO approved Anthropic's terms; when it is enabled, restrict it to the approved groups and record the decision.

Portal: <https://admin.microsoft.com/>

## References

- [Anthropic models in Microsoft Online Services: models with Data Retention](https://learn.microsoft.com/en-us/microsoft-365/copilot/connect-to-ai-subprocessor)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
