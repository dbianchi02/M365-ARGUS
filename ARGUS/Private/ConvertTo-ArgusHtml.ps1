function ConvertTo-ArgusHtml {
    <#
    .SYNOPSIS
        Renders the self-contained HTML report from a results JSON string.

    .DESCRIPTION
        - Parses the JSON with System.Text.Json (string values such as timestamps are kept verbatim).
        - Caps each check's Findings at -MaxFindingsInHtml and records the original count in FindingsTotal.
        - Optionally embeds a logo (png, jpg, gif, svg; max 1 MB) as a data URI in Report.LogoDataUri.
        - Serialises with JavaScriptEncoder.Default, which escapes <, >, &, quotes and non-ASCII
          characters as \uXXXX, so tenant strings can never close the <script> element; '</' is escaped too.
        - Inlines report.css and report.js into template.html.
        Tenant data is only rendered client-side with textContent (see report.js).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Json,

        [Parameter()]
        [ValidateRange(0, 100000)]
        [int] $MaxFindingsInHtml = 500,

        [Parameter()]
        [string] $LogoPath
    )

    $reportRoot = Join-Path $script:ArgusModuleRoot 'Report'
    $template = Get-Content -LiteralPath (Join-Path $reportRoot 'template.html') -Raw
    $css = Get-Content -LiteralPath (Join-Path $reportRoot 'report.css') -Raw
    $js = Get-Content -LiteralPath (Join-Path $reportRoot 'report.js') -Raw
    if ($css -match '</style' -or $js -match '</script') {
        throw 'Report assets must not contain closing </style> or </script> sequences.'
    }

    try {
        $root = [System.Text.Json.Nodes.JsonNode]::Parse($Json)
    }
    catch {
        throw "The results JSON could not be parsed: $($_.Exception.Message)"
    }
    if ($root -isnot [System.Text.Json.Nodes.JsonObject]) {
        throw 'The results JSON must be an object.'
    }

    $results = $root['Results']
    if ($results -is [System.Text.Json.Nodes.JsonArray]) {
        foreach ($result in $results) {
            if ($result -isnot [System.Text.Json.Nodes.JsonObject]) { continue }
            $findings = $result['Findings']
            $total = 0
            if ($findings -is [System.Text.Json.Nodes.JsonArray]) {
                $total = $findings.Count
                while ($findings.Count -gt $MaxFindingsInHtml) { $findings.RemoveAt($findings.Count - 1) }
            }
            $result['FindingsTotal'] = [System.Text.Json.Nodes.JsonNode]$total
        }
    }

    if ($root['Run'] -is [System.Text.Json.Nodes.JsonObject]) {
        $root['Run']['MaxFindingsInHtml'] = [System.Text.Json.Nodes.JsonNode]$MaxFindingsInHtml
    }

    if ($LogoPath) {
        $mimeTypes = @{ '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif'; '.svg' = 'image/svg+xml' }
        $extension = [System.IO.Path]::GetExtension($LogoPath).ToLowerInvariant()
        if (-not (Test-Path -LiteralPath $LogoPath -PathType Leaf)) {
            Write-Warning "Logo '$LogoPath' not found; the report is rendered without a logo."
        }
        elseif (-not $mimeTypes.ContainsKey($extension)) {
            Write-Warning "Logo '$LogoPath' is not a png, jpg, gif or svg file; the report is rendered without a logo."
        }
        elseif ((Get-Item -LiteralPath $LogoPath).Length -gt 1MB) {
            Write-Warning "Logo '$LogoPath' is larger than 1 MB; the report is rendered without a logo."
        }
        else {
            $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $LogoPath).ProviderPath)
            $dataUri = "data:$($mimeTypes[$extension]);base64,$([Convert]::ToBase64String($bytes))"
            if ($root['Report'] -isnot [System.Text.Json.Nodes.JsonObject]) {
                $root['Report'] = [System.Text.Json.Nodes.JsonObject]::new()
            }
            $root['Report']['LogoDataUri'] = [System.Text.Json.Nodes.JsonNode]$dataUri
        }
    }

    $options = [System.Text.Json.JsonSerializerOptions]::new()
    $options.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::Default
    $payload = $root.ToJsonString($options).Replace('</', '<\/')

    $html = $template.Replace('/*__ARGUS_CSS__*/', $css).Replace('/*__ARGUS_JS__*/', $js)
    $marker = '__ARGUS_DATA__'
    $index = $html.IndexOf($marker, [System.StringComparison]::Ordinal)
    if ($index -lt 0) { throw 'Report template is missing the data placeholder.' }
    $html.Substring(0, $index) + $payload + $html.Substring($index + $marker.Length)
}
