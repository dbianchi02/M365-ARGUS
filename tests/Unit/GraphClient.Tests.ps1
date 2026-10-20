#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Invoke-ArgusGraphRequest' {
    BeforeEach {
        Mock Start-Sleep -ModuleName ARGUS { }
    }

    It 'builds v1.0 and beta URLs from relative paths' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ id = 'x' } }
        InModuleScope ARGUS {
            $null = Invoke-ArgusGraphRequest -Uri '/organization'
            $null = Invoke-ArgusGraphRequest -Uri 'policies/authorizationPolicy' -Beta
        }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/v1.0/organization' -and $Method -eq 'GET' }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/policies/authorizationPolicy' }
    }

    It 'follows @odata.nextLink with -All' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS {
            if ($Uri -like '*skiptoken=2*') { return [pscustomobject]@{ value = @([pscustomobject]@{ id = 3 }) } }
            [pscustomobject]@{ value = @([pscustomobject]@{ id = 1 }, [pscustomobject]@{ id = 2 }); '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?$skiptoken=2' }
        }
        $ids = InModuleScope ARGUS { @(Invoke-ArgusGraphRequest -Uri '/users' -All).id }
        $ids | Should -Be @(1, 2, 3)
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 2 -Exactly
    }

    It 'returns only the first page without -All' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS {
            [pscustomobject]@{ value = @([pscustomobject]@{ id = 1 }); '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?$skiptoken=2' }
        }
        $items = InModuleScope ARGUS { @(Invoke-ArgusGraphRequest -Uri '/users') }
        $items.Count | Should -Be 1
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly
    }

    It 'returns a single entity as one object' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ id = 'authorizationPolicy'; allowInvitesFrom = 'everyone' } }
        $policy = InModuleScope ARGUS { Invoke-ArgusGraphRequest -Uri '/policies/authorizationPolicy' }
        $policy.allowInvitesFrom | Should -Be 'everyone'
    }

    It 'keeps an entity with its own value property intact with -Raw' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ id = 'microsoft.copilot.allowwebsearch'; value = '1'; policyId = 'p1' } }
        $setting = InModuleScope ARGUS { Invoke-ArgusGraphRequest -Uri '/copilot/admin/policySettings/microsoft.copilot.allowwebsearch' -Beta -Raw }
        $setting.id | Should -Be 'microsoft.copilot.allowwebsearch'
        $setting.value | Should -Be '1'
    }

    It 'adds ConsistencyLevel and $count for advanced queries' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ value = @() } }
        InModuleScope ARGUS { $null = Invoke-ArgusGraphRequest -Uri '/users?$filter=endswith(mail,''x'')' -Advanced }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter {
            $Headers['ConsistencyLevel'] -eq 'eventual' -and $Uri -like '*&$count=true'
        }
    }

    It 'refuses <Method> without sending a request' -ForEach @(@{ Method = 'POST' }, @{ Method = 'PATCH' }, @{ Method = 'PUT' }, @{ Method = 'DELETE' }) {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { }
        InModuleScope ARGUS -Parameters @{ Method = $Method } {
            { Invoke-ArgusGraphRequest -Uri '/users' -Method $Method } | Should -Throw '*read-only*'
        }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 0 -Exactly
    }

    It 'refuses hosts other than Microsoft Graph' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { }
        InModuleScope ARGUS {
            { Invoke-ArgusGraphRequest -Uri 'https://example.invalid/v1.0/users' } | Should -Throw '*only https://graph.microsoft.com*'
            { Invoke-ArgusGraphRequest -Uri 'http://graph.microsoft.com/v1.0/users' } | Should -Throw '*only https://graph.microsoft.com*'
        }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 0 -Exactly
    }

    It 'retries 429 using Retry-After' {
        $script:calls = 0
        Mock Invoke-MgGraphRequest -ModuleName ARGUS {
            $script:calls++
            if ($script:calls -eq 1) { throw [System.Exception]::new('Response status code does not indicate success: 429 (Too Many Requests). Retry-After: 7') }
            [pscustomobject]@{ value = @([pscustomobject]@{ id = 1 }) }
        }
        $items = InModuleScope ARGUS { @(Invoke-ArgusGraphRequest -Uri '/users' -All) }
        $items.Count | Should -Be 1
        Should -Invoke Start-Sleep -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Seconds -eq 7 }
    }

    It 'retries 503 with exponential backoff' {
        $script:calls = 0
        Mock Invoke-MgGraphRequest -ModuleName ARGUS {
            $script:calls++
            if ($script:calls -le 2) { throw [System.Exception]::new('Response status code does not indicate success: ServiceUnavailable (Service Unavailable).') }
            [pscustomobject]@{ value = @() }
        }
        InModuleScope ARGUS { $null = Invoke-ArgusGraphRequest -Uri '/users' }
        Should -Invoke Start-Sleep -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Seconds -eq 2 }
        Should -Invoke Start-Sleep -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Seconds -eq 4 }
    }

    It 'gives up after MaxRetries and rethrows' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { throw [System.Exception]::new('Response status code does not indicate success: 429 (Too Many Requests).') }
        InModuleScope ARGUS {
            { Invoke-ArgusGraphRequest -Uri '/users' -MaxRetries 3 } | Should -Throw '*429*'
        }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 4 -Exactly
    }

    It 'does not retry 403' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { throw [System.Exception]::new('Response status code does not indicate success: Forbidden (Forbidden).') }
        InModuleScope ARGUS { { Invoke-ArgusGraphRequest -Uri '/users' } | Should -Throw '*Forbidden*' }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly
        Should -Invoke Start-Sleep -ModuleName ARGUS -Times 0 -Exactly
    }

    It 'passes -OutputFilePath for downloads' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { }
        InModuleScope ARGUS { Invoke-ArgusGraphRequest -Uri "/reports/getTeamsTeamActivityDetail(period='D180')" -OutputFilePath 'x.csv' }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $OutputFilePath -eq 'x.csv' -and $Method -eq 'GET' }
    }
}

Describe 'Get-ArgusGraphError' {
    It 'reads the status code and Retry-After from an HttpResponseMessage' {
        InModuleScope ARGUS {
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
            $response.Headers.RetryAfter = [System.Net.Http.Headers.RetryConditionHeaderValue]::new([timespan]::FromSeconds(3))
            $exception = [System.Exception]::new('throttled')
            $exception | Add-Member -NotePropertyName Response -NotePropertyValue $response
            $record = [System.Management.Automation.ErrorRecord]::new($exception, 'id', 'NotSpecified', $null)
            $info = Get-ArgusGraphError -ErrorRecord $record
            $info.StatusCode | Should -Be 429
            $info.RetryAfter | Should -Be 3
            $info.Transient | Should -BeTrue
        }
    }

    It 'parses status names from the message' {
        InModuleScope ARGUS {
            $record = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('Response status code does not indicate success: NotFound (Not Found).'), 'id', 'NotSpecified', $null)
            (Get-ArgusGraphError -ErrorRecord $record).StatusCode | Should -Be 404
        }
    }
}

Describe 'Invoke-ArgusGraphBatch' {
    BeforeEach {
        Mock Start-Sleep -ModuleName ARGUS { }
    }

    It 'sends at most 20 GET sub-requests per batch and returns results in input order' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS {
            $body = $Body | ConvertFrom-Json
            [pscustomobject]@{ responses = @($body.requests | ForEach-Object { [pscustomobject]@{ id = $_.id; status = 200; body = [pscustomobject]@{ url = $_.url; method = $_.method } } }) }
        }
        $results = InModuleScope ARGUS {
            $requests = 1..25 | ForEach-Object { @{ Id = "g$_"; Url = "/groups/$_/owners?`$select=id" } }
            @(Invoke-ArgusGraphBatch -Request $requests)
        }
        $results.Count | Should -Be 25
        $results[0].Id | Should -Be 'g1'
        $results[24].Body.url | Should -Be '/groups/25/owners?$select=id'
        ($results.Body.method | Sort-Object -Unique) | Should -Be 'GET'
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 2 -Exactly -ParameterFilter { $Method -eq 'POST' -and $Uri -eq 'https://graph.microsoft.com/v1.0/$batch' }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { @(($Body | ConvertFrom-Json).requests).Count -eq 20 }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { @(($Body | ConvertFrom-Json).requests).Count -eq 5 }
    }

    It 'retries throttled sub-requests using their Retry-After header' {
        $script:round = 0
        Mock Invoke-MgGraphRequest -ModuleName ARGUS {
            $script:round++
            $body = $Body | ConvertFrom-Json
            [pscustomobject]@{ responses = @($body.requests | ForEach-Object {
                        if ($script:round -eq 1 -and $_.id -eq 'b') { [pscustomobject]@{ id = 'b'; status = 429; headers = [pscustomobject]@{ 'Retry-After' = '5' } } }
                        else { [pscustomobject]@{ id = $_.id; status = 200; body = [pscustomobject]@{ value = @() } } }
                    })
            }
        }
        $results = InModuleScope ARGUS { @(Invoke-ArgusGraphBatch -Request @(@{ Id = 'a'; Url = '/a' }, @{ Id = 'b'; Url = '/b' })) }
        ($results | Where-Object Id -EQ 'b').Status | Should -Be 200
        Should -Invoke Start-Sleep -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Seconds -eq 5 }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { @(($Body | ConvertFrom-Json).requests).Count -eq 1 }
    }

    It 'rejects <Name>' -ForEach @(
        @{ Name = 'non-GET sub-requests'; Request = @(@{ Id = '1'; Url = '/groups/1'; Method = 'DELETE' }); Message = '*read-only*' }
        @{ Name = 'absolute URLs'; Request = @(@{ Id = '1'; Url = 'https://graph.microsoft.com/v1.0/users' }); Message = '*relative URL*' }
        @{ Name = 'duplicate Ids'; Request = @(@{ Id = '1'; Url = '/a' }, @{ Id = '1'; Url = '/b' }); Message = '*unique*' }
    ) {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { }
        InModuleScope ARGUS -Parameters @{ Request = $Request; Message = $Message } {
            { Invoke-ArgusGraphBatch -Request $Request } | Should -Throw -ExpectedMessage $Message
        }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 0 -Exactly
    }
}

Describe 'Invoke-ArgusGraphReport' {
    It 'downloads the CSV, returns its rows and deletes the temporary file' {
        $script:savedPath = $null
        Mock Invoke-MgGraphRequest -ModuleName ARGUS {
            $script:savedPath = $OutputFilePath
            Set-Content -LiteralPath $OutputFilePath -Value "Report Refresh Date,Team Name,Team Id,Last Activity Date`n2026-10-18,Sales,t1,2026-01-02`n2026-10-18,Ops,t2," -Encoding utf8BOM
        }
        $rows = InModuleScope ARGUS { @(Invoke-ArgusGraphReport -Name 'getTeamsTeamActivityDetail' -Period D180) }
        $rows.Count | Should -Be 2
        $rows[0].'Team Id' | Should -Be 't1'
        $rows[1].'Last Activity Date' | Should -Be ''
        Test-Path -LiteralPath $script:savedPath | Should -BeFalse
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Uri -eq "https://graph.microsoft.com/v1.0/reports/getTeamsTeamActivityDetail(period='D180')" }
    }
}
