#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeDiscovery {
    # Headless Chromium-based browser used to verify client-side rendering (skipped when absent).
    $script:browser = @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
        '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/microsoft-edge'
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    $script:reportRoot = Join-Path $PSScriptRoot '../../ARGUS/Report'
    $script:fixture = Join-Path $PSScriptRoot '../Fixtures/sample-results.json'
    $script:fixtureJson = Get-Content -LiteralPath $script:fixture -Raw

    function Get-EmbeddedData {
        param([string] $Html)
        $match = [regex]::Match($Html, '<script type="application/json" id="argus-data">(.*?)</script>', 'Singleline')
        $match.Success | Should -BeTrue
        $match.Groups[1].Value | ConvertFrom-Json -Depth 50
    }
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Report assets' {
    It 'have no external dependencies' {
        foreach ($name in 'template.html', 'report.css', 'report.js') {
            $content = Get-Content -LiteralPath (Join-Path $script:reportRoot $name) -Raw
            $content | Should -Not -Match '(?i)<script[^>]+src=' -Because "$name must not load scripts"
            $content | Should -Not -Match '(?i)<link[^>]+href="(?!data:)' -Because "$name must not load stylesheets or remote icons (data: URIs only)"
            $content | Should -Not -Match '(?i)@import' -Because "$name must not import CSS"
            $content | Should -Not -Match '(?i)url\(\s*[''"]?https?:' -Because "$name must not load remote assets"
            $content | Should -Not -Match '(?i)fetch\(|XMLHttpRequest|WebSocket|EventSource|sendBeacon' -Because "$name must not use the network"
        }
    }

    It 'never writes HTML strings to the DOM in report.js' {
        $js = Get-Content -LiteralPath (Join-Path $script:reportRoot 'report.js') -Raw
        $code = [regex]::Replace($js, '(?s)/\*.*?\*/', '')
        $code | Should -Not -Match '\.innerHTML|\.outerHTML|insertAdjacentHTML|document\.write|\beval\(|new Function\(|createContextualFragment'
    }

    It 'embeds the favicon as an inline SVG data URI' {
        $template = Get-Content -LiteralPath (Join-Path $script:reportRoot 'template.html') -Raw
        $template | Should -Match '<link rel="icon" type="image/svg\+xml" href="data:image/svg\+xml,'
    }

    It 'declares a restrictive Content-Security-Policy' {
        $template = Get-Content -LiteralPath (Join-Path $script:reportRoot 'template.html') -Raw
        $template | Should -Match "Content-Security-Policy"
        $template | Should -Match "default-src 'none'"
        $template | Should -Match "img-src data:"
    }
}

Describe 'ConvertTo-ArgusHtml' {
    BeforeAll {
        $script:html = InModuleScope ARGUS -Parameters @{ Json = $script:fixtureJson } {
            ConvertTo-ArgusHtml -Json $Json -MaxFindingsInHtml 500
        }
    }

    It 'inlines CSS, JS and data and leaves no placeholder' {
        $script:html | Should -Not -Match '__ARGUS_(CSS|JS|DATA)__'
        $script:html | Should -Match '--fail:'
        $script:html | Should -Match 'function renderDetail'
    }

    It 'contains exactly two script elements (data and renderer)' {
        ([regex]::Matches($script:html, '(?i)<script')).Count | Should -Be 2
        ([regex]::Matches($script:html, '(?i)</script')).Count | Should -Be 2
    }

    It 'escapes tenant strings inside the embedded JSON' {
        $script:html | Should -Not -Match '<script>alert\(1\)'
        $script:html | Should -Not -Match '<img src=x'
        $script:html | Should -Match '\\u003Cscript\\u003Ealert\(1\)'
    }

    It 'caps findings and records the original count' {
        $data = Get-EmbeddedData -Html $script:html
        $devices = $data.Results | Where-Object Id -EQ 'ARG.ENT.014'
        @($devices.Findings).Count | Should -Be 500
        $devices.FindingsTotal | Should -Be 3000
        $groups = $data.Results | Where-Object Id -EQ 'ARG.GRP.007'
        @($groups.Findings).Count | Should -Be 11
        $groups.FindingsTotal | Should -Be 11
        ($groups.Findings | Where-Object DisplayName -EQ '<script>alert(1)</script>') | Should -Not -BeNullOrEmpty
    }

    It 'keeps timestamps verbatim' {
        $script:html | Should -Match '"StartedAt":"2026-10-19T09:00:00(\.0+)?\\u002B02:00"'
    }

    It 'honours MaxFindingsInHtml = 0' {
        $html = InModuleScope ARGUS -Parameters @{ Json = $script:fixtureJson } { ConvertTo-ArgusHtml -Json $Json -MaxFindingsInHtml 0 }
        $data = Get-EmbeddedData -Html $html
        ($data.Results | ForEach-Object { @($_.Findings).Count } | Measure-Object -Sum).Sum | Should -Be 0
        ($data.Results | Where-Object Id -EQ 'ARG.ENT.014').FindingsTotal | Should -Be 3000
        $data.Run.MaxFindingsInHtml | Should -Be 0
    }

    It 'embeds a logo as a data URI' {
        $logo = Join-Path $TestDrive 'logo.png'
        [System.IO.File]::WriteAllBytes($logo, [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII='))
        $html = InModuleScope ARGUS -Parameters @{ Json = $script:fixtureJson; Logo = $logo } { ConvertTo-ArgusHtml -Json $Json -LogoPath $Logo }
        (Get-EmbeddedData -Html $html).Report.LogoDataUri | Should -BeLike 'data:image/png;base64,iVBOR*'
    }

    It 'ignores an unsupported logo with a warning' {
        $logo = Join-Path $TestDrive 'logo.exe'
        Set-Content -LiteralPath $logo -Value 'x'
        $html = InModuleScope ARGUS -Parameters @{ Json = $script:fixtureJson; Logo = $logo } {
            ConvertTo-ArgusHtml -Json $Json -LogoPath $Logo -WarningVariable warnings -WarningAction SilentlyContinue
            ($warnings | Out-String) | Should -BeLike '*not a png, jpg, gif or svg*'
        }
        (Get-EmbeddedData -Html $html).Report.PSObject.Properties.Name | Should -Not -Contain 'LogoDataUri'
    }

    It 'rejects invalid JSON' {
        InModuleScope ARGUS { { ConvertTo-ArgusHtml -Json '{ not json' } | Should -Throw '*could not be parsed*' }
    }
}

Describe 'Export-ArgusReport' {
    BeforeAll {
        Mock Open-ArgusFile -ModuleName ARGUS { }
    }

    It 'writes the HTML next to the JSON by default and opens it' {
        $json = Join-Path $TestDrive 'run.json'
        Copy-Item -LiteralPath $script:fixture -Destination $json
        $file = Export-ArgusReport -InputPath $json
        $file.FullName | Should -Be ([System.IO.Path]::ChangeExtension($json, '.html'))
        Should -Invoke Open-ArgusFile -ModuleName ARGUS -Times 1 -Exactly
    }

    It 'honours -OutputPath and -NoBrowser' {
        $target = Join-Path $TestDrive 'out/report.html'
        $file = Export-ArgusReport -InputPath $script:fixture -OutputPath $target -NoBrowser
        Test-Path -LiteralPath $target | Should -BeTrue
        $file.Length | Should -BeGreaterThan 10000
        Should -Invoke Open-ArgusFile -ModuleName ARGUS -Times 0 -Exactly
    }

    It 'uses Run.MaxFindingsInHtml from the file unless the parameter is given' {
        $json = Join-Path $TestDrive 'small.json'
        $content = $script:fixtureJson -replace '"MaxFindingsInHtml": 500', '"MaxFindingsInHtml": 20'
        Set-Content -LiteralPath $json -Value $content -Encoding utf8
        $html = Get-Content -LiteralPath (Export-ArgusReport -InputPath $json -NoBrowser).FullName -Raw
        @((Get-EmbeddedData -Html $html).Results | Where-Object Id -EQ 'ARG.ENT.014').Findings.Count | Should -Be 20
        $html = Get-Content -LiteralPath (Export-ArgusReport -InputPath $json -NoBrowser -MaxFindingsInHtml 5).FullName -Raw
        @((Get-EmbeddedData -Html $html).Results | Where-Object Id -EQ 'ARG.ENT.014').Findings.Count | Should -Be 5
    }

    It 'rejects <Name>' -ForEach @(
        @{ Name = 'an unsupported schema version'; Content = '{ "SchemaVersion": "2.0", "Results": [] }'; Message = '*unsupported SchemaVersion*' }
        @{ Name = 'a file without schema version'; Content = '{ "Results": [] }'; Message = '*unsupported SchemaVersion*' }
        @{ Name = 'invalid JSON'; Content = 'nope'; Message = '*not valid JSON*' }
    ) {
        $json = Join-Path $TestDrive 'bad.json'
        Set-Content -LiteralPath $json -Value $Content
        { Export-ArgusReport -InputPath $json -NoBrowser } | Should -Throw -ExpectedMessage $Message
    }

    It 'throws on a missing file' {
        { Export-ArgusReport -InputPath (Join-Path $TestDrive 'missing.json') -NoBrowser } | Should -Throw '*not found*'
    }
}

Describe 'Invoke-Argus HTML output' {
    BeforeAll {
        Mock Write-ArgusRunSummary -ModuleName ARGUS { }
        Mock Open-ArgusFile -ModuleName ARGUS { }
    }

    It 'writes HTML and JSON with the same base name' {
        $out = Join-Path $TestDrive 'invoke'
        $null = Invoke-Argus -CustomCheckPath (Join-Path $PSScriptRoot '../Fixtures/FakeChecks') -OutputPath $out -NoBrowser -WarningAction SilentlyContinue
        $html = @(Get-ChildItem -LiteralPath $out -Filter '*.html')
        $json = @(Get-ChildItem -LiteralPath $out -Filter '*.json')
        $html.Count | Should -Be 1
        $html[0].BaseName | Should -Be $json[0].BaseName
        Should -Invoke Open-ArgusFile -ModuleName ARGUS -Times 0 -Exactly
        (Get-Content -LiteralPath $html[0].FullName -Raw) | Should -Not -Match '<script>alert\(1\)'
    }

    It 'opens the report unless -NoBrowser is set' {
        $null = Invoke-Argus -CustomCheckPath (Join-Path $PSScriptRoot '../Fixtures/FakeChecks') -OutputPath (Join-Path $TestDrive 'open') -OutputFormat Html -WarningAction SilentlyContinue
        Should -Invoke Open-ArgusFile -ModuleName ARGUS -Times 1 -Exactly
    }
}

Describe 'Rendered report in a headless browser' -Skip:(-not $script:browser) {
    BeforeAll {
        $script:browserPath = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
            '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/microsoft-edge'
            '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
        ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1

        $page = Join-Path $TestDrive 'report.html'
        $null = Export-ArgusReport -InputPath $script:fixture -OutputPath $page -NoBrowser
        $uri = ([System.Uri]$page).AbsoluteUri + '#ARG.GRP.007'
        # The profile lives outside TestDrive: browser helper processes can keep files locked briefly.
        $script:profileDir = Join-Path ([System.IO.Path]::GetTempPath()) ('argus-browser-' + [guid]::NewGuid().ToString('N'))
        $stdout = Join-Path $TestDrive 'dom.html'
        $arguments = @('--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check', '--dump-dom')
        if ($IsWindows) {
            # Start-Process joins the arguments into one command line: quote the profile path.
            $arguments += @("--user-data-dir=`"$script:profileDir`"", $uri)
            $null = Start-Process -FilePath $script:browserPath -ArgumentList $arguments -RedirectStandardOutput $stdout `
                -RedirectStandardError (Join-Path $TestDrive 'browser.log') -Wait -PassThru -NoNewWindow
            $script:dom = Get-Content -LiteralPath $stdout -Raw
        }
        else {
            # Native invocation passes every argument unchanged; Start-Process re-parses the joined command line
            # on Linux and the browser opened a New Tab page instead of the report.
            $arguments += @('--no-sandbox', "--user-data-dir=$script:profileDir", $uri)
            $script:dom = & $script:browserPath @arguments 2> (Join-Path $TestDrive 'browser.log') | Out-String
        }
    }

    AfterAll {
        Remove-Item -LiteralPath $script:profileDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'renders the page' {
        $script:dom | Should -Match 'class="appbar-inner"'
        $script:dom | Should -Match 'Contoso Ltd \(fictitious\)'
    }

    It 'opens the deep-linked check and renders its findings' {
        $script:dom | Should -Match '<details class="check" id="ARG\.GRP\.007" open'
        $script:dom | Should -Match 'Microsoft 365 \(Unified\) groups'
    }

    It 'shows a script-tag display name as text, not as an element' {
        $script:dom | Should -Match '<td[^>]*>&lt;script&gt;alert\(1\)&lt;/script&gt;</td>'
        ([regex]::Matches($script:dom, '(?i)<script')).Count | Should -Be 2
    }

    It 'shows an img-onerror display name as text, not as an element' {
        $script:dom | Should -Match '<td[^>]*>&lt;img src=x onerror=alert\(2\)&gt;</td>'
        $script:dom | Should -Not -Match '(?i)<img[^>]+onerror'
    }
}
