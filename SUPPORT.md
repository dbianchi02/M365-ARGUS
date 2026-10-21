# Getting help

| You want to… | Go to |
|---|---|
| Ask how to install, connect or run ARGUS, or how to read a result | [Discussions › Q&A](https://github.com/dbianchi02/M365-ARGUS/discussions/categories/q-a) |
| Propose a new check or an idea | [Discussions › Ideas](https://github.com/dbianchi02/M365-ARGUS/discussions/categories/ideas), or a [check request](https://github.com/dbianchi02/M365-ARGUS/issues/new?template=check_request.yml) when it is well defined |
| Report a bug (wrong result, error, crash, report rendering) | [Bug report](https://github.com/dbianchi02/M365-ARGUS/issues/new?template=bug_report.yml) |
| Report a vulnerability | [Private vulnerability report](https://github.com/dbianchi02/M365-ARGUS/security/advisories/new), see [SECURITY.md](SECURITY.md) |

Before asking, it often helps to run:

```powershell
Test-ArgusPrerequisite                     # missing modules, connections, scopes, licences
Get-ArgusRequiredPermission -Id <check id> # what a check needs
Invoke-Argus -Id <check id> -Verbose       # run one check with details
```

ARGUS is maintained in spare time: answers are best effort. Please never post tenant names, user names,
reports or screenshots from a real tenant; replace them with fictitious values.
