# ARG.COP.004 — Anthropic models as a Microsoft subprocessor (manual review)

| | |
|---|---|
| Area | Copilot |
| Category | AI data processing |
| Severity | Info |
| Services | Graph |
| Graph permissions (read-only) | `Organization.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | — |
| Data sets | Organization |
| Uses Graph beta | No |
| Tags | Copilot, AI, GDPR, Manual |

## What is checked

The "AI providers operating as Microsoft subprocessors" setting (Microsoft 365 admin center > Copilot > Settings) controls whether Anthropic models can be used in Copilot, Researcher, Copilot Studio, Power Platform and Copilot in Microsoft 365 apps. No Microsoft API exposes it, so this check is always To review: it reads the tenant country (`organization.countryLetterCode`) and states the default that applies. Anthropic is on by default in the commercial cloud and off by default in the EU, EFTA and the UK. Info severity: it does not change the score.

## Why it matters

As a Microsoft subprocessor Anthropic is covered by the Microsoft Product Terms and DPA, but Anthropic models are excluded from the EU Data Boundary and from in-country processing commitments. For organisations subject to the GDPR this is a data-transfer decision that should be documented (records of processing, DPIA where required) and limited to approved users.

## How to fix

1. In the Microsoft 365 admin center, go to Copilot > Settings > View all > AI providers operating as Microsoft subprocessors.
2. Check whether Anthropic is enabled and who can access it (all users, or specific users and groups).
3. If it is enabled, record the decision and its legal basis; limit access to approved groups, or select Disable Anthropic as a Microsoft subprocessor.
4. Also review Copilot in Microsoft 365 apps with Anthropic models, a separate setting for Word, Excel and PowerPoint.

Portal: <https://admin.microsoft.com/>

## References

- [Anthropic models in Microsoft Online Services](https://learn.microsoft.com/en-us/microsoft-365/copilot/connect-to-ai-subprocessor)
- [Copilot in Microsoft 365 apps with Anthropic models](https://learn.microsoft.com/en-us/microsoft-365/copilot/copilot-anthropic-apps)
- [What is the EU Data Boundary?](https://learn.microsoft.com/en-us/privacy/eudb/eu-data-boundary-learn)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
