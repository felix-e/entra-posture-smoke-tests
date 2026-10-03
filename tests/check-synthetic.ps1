$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'src/PostureChecks.psm1') -Force
$manifest = Get-Content (Join-Path $root 'MaesterTags.json') -Raw | ConvertFrom-Json -AsHashtable
$snapshot = Get-Content (Join-Path $root 'fixtures/snapshot.json') -Raw | ConvertFrom-Json -AsHashtable
$now = [datetimeoffset]::Parse('2026-01-15T00:00:00Z')
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$expectedDomains = @('app-lifecycle','auth-credentials','agents-nhi')
$expectedTotals = @(16,14,9)
$allIds = @()
for ($i = 0; $i -lt 3; $i++) {
    $domain = $manifest.domains[$i]
    Assert ($domain.id -ceq $expectedDomains[$i]) 'Wrong domain'
    Assert (($domain.upstream.Count + $domain.custom.Count) -eq $expectedTotals[$i]) 'Wrong domain count'
    $allIds += $domain.upstream + $domain.custom
}
Assert (($allIds | Select-Object -Unique).Count -eq 39) 'Manifest IDs not unique'
Assert (($manifest.domains.upstream | ForEach-Object { $_ }).Count -eq 26) 'Wrong upstream count'
$custom = @($manifest.domains | ForEach-Object { $_.custom })
Assert ($custom.Count -eq 13) 'Wrong custom count'
$expectedCustom = @('LOCAL.PERM.001','LOCAL.PERM.002','LOCAL.PERM.003','LOCAL.OWNER.001','LOCAL.OWNER.002','LOCAL.OWNER.003','LOCAL.CRED.001','LOCAL.CRED.002','LOCAL.CRED.003','LOCAL.CRED.004','LOCAL.CA.001','LOCAL.CA.002','LOCAL.CA.003')
Assert ((@($custom | Sort-Object) -join ',') -ceq (@($expectedCustom | Sort-Object) -join ',')) 'Unexpected custom IDs'
$caseFiles = @{
    'Test-Permissions.Tests.ps1' = @('LOCAL.PERM.001','LOCAL.PERM.002','LOCAL.PERM.003')
    'Test-Ownership.Tests.ps1' = @('LOCAL.OWNER.001','LOCAL.OWNER.002','LOCAL.OWNER.003')
    'Test-Credentials.Tests.ps1' = @('LOCAL.CRED.001','LOCAL.CRED.002','LOCAL.CRED.003','LOCAL.CRED.004')
    'Test-ConditionalAccess.Tests.ps1' = @('LOCAL.CA.001','LOCAL.CA.002','LOCAL.CA.003')
}
$files = @(Get-ChildItem (Join-Path $root 'maester-tests/Custom') -Filter '*.Tests.ps1' -File)
Assert ($files.Count -eq 4) 'Expected exactly four Pester files'
Assert ((@($files.Name | Sort-Object) -join ',') -ceq (@($caseFiles.Keys | Sort-Object) -join ',')) 'Unexpected Pester file names'
$caseIds = @()
foreach ($file in $files) {
    $source = Get-Content $file.FullName -Raw
    $ids = @([regex]::Matches($source, "\bid\s*=\s*'(LOCAL\.[A-Z]+\.\d{3})'") | ForEach-Object { $_.Groups[1].Value })
    Assert ((@($ids | Sort-Object) -join ',') -ceq (@($caseFiles[$file.Name] | Sort-Object) -join ',')) "Wrong cases in $($file.Name)"
    Assert ($source.Contains('Test-PostureChecks -Snapshot')) "File does not call shared evaluator: $($file.Name)"
    $caseIds += $ids
}
Assert ($caseIds.Count -eq 13 -and @($caseIds | Select-Object -Unique).Count -eq 13) 'Pester cases must cover 13 distinct IDs'
Assert ((@($caseIds | Sort-Object) -join ',') -ceq (@($custom | Sort-Object) -join ',')) 'Pester cases differ from manifest'
$baseline = @(Test-PostureChecks -Snapshot $snapshot -Now $now)
Assert ($baseline.Count -eq 13) 'Expected 13 checks'
Assert ((@($baseline.id | Sort-Object) -join ',') -ceq (@($custom | Sort-Object) -join ',')) 'Custom IDs differ from manifest'
foreach ($check in $baseline) { Assert (-not $check.pass -and $check.count -gt 0) "Expected fixture violation: $($check.id)" }
Assert ((@($baseline | Where-Object id -eq 'LOCAL.CRED.004')[0].count) -eq 2) 'Expected two secret-only applications'
function Clone($obj) { return (ConvertFrom-Json -AsHashtable (ConvertTo-Json -InputObject $obj -Depth 30)) }
# A clean control must pass every rule, including empty (but present) collections.
$clean = Clone $snapshot
$clean.applications = @($clean.applications[0])
$clean.servicePrincipals = @($clean.servicePrincipals[0])
$clean.conditionalAccessPolicies[0].excludedUserIds = @('user-allowed@example.org')
$clean.conditionalAccessPolicies[0].excludedGroups = @($clean.conditionalAccessPolicies[0].excludedGroups[0])
$good = @(Test-PostureChecks -Snapshot $clean -Now $now)
Assert ((@($good | Where-Object { -not $_.pass -or $_.count -ne 0 })).Count -eq 0) 'Clean control failed'
# Negative controls: missing evidence must not silently become a pass.
$missingRoles = Clone $clean
$missingRoles.applications[0].Remove('requestedRoles')
Assert (-not (@(Test-PostureChecks -Snapshot $missingRoles -Now $now) | Where-Object id -eq 'LOCAL.PERM.001').pass) 'Missing roles passed'
$missingEnd = Clone $clean
$missingEnd.applications[0].credentials[0].Remove('endDateTime')
Assert (-not (@(Test-PostureChecks -Snapshot $missingEnd -Now $now) | Where-Object id -eq 'LOCAL.CRED.001').pass) 'Missing end date passed'
$missingGroup = Clone $clean
$missingGroup.config.exceptionGroups[0].Remove('owner')
Assert (-not (@(Test-PostureChecks -Snapshot $missingGroup -Now $now) | Where-Object id -eq 'LOCAL.CA.003').pass) 'Missing group owner passed'
$missingUsers = Clone $clean
$missingUsers.conditionalAccessPolicies[0].Remove('excludedUserIds')
Assert (-not (@(Test-PostureChecks -Snapshot $missingUsers -Now $now) | Where-Object id -eq 'LOCAL.CA.001').pass) 'Missing exclusions passed'
$staleReview = Clone $clean
$staleReview.config.exceptionGroups[0].lastReviewedAt = '2024-01-01T00:00:00Z'
Assert (-not (@(Test-PostureChecks -Snapshot $staleReview -Now $now) | Where-Object id -eq 'LOCAL.CA.003').pass) 'Stale review passed'
$missingType = Clone $clean
$missingType.servicePrincipals[0].Remove('servicePrincipalType')
Assert (-not (@(Test-PostureChecks -Snapshot $missingType -Now $now) | Where-Object id -eq 'LOCAL.OWNER.003').pass) 'Missing service principal type passed'
$managedIdentity = Clone $clean
$managedIdentity.servicePrincipals[0].servicePrincipalType = 'ManagedIdentity'
Assert ((@(Test-PostureChecks -Snapshot $managedIdentity -Now $now) | Where-Object id -eq 'LOCAL.OWNER.003').pass) 'Managed identity incorrectly treated as an application'
$emptyRisk = Clone $clean
$emptyRisk.config.riskyRoleIds = @()
Assert (-not (@(Test-PostureChecks -Snapshot $emptyRisk -Now $now) | Where-Object id -eq 'LOCAL.PERM.001').pass) 'Empty risk policy passed'
$emptyApps = Clone $emptyRisk
$emptyApps.applications = @()
Assert (-not (@(Test-PostureChecks -Snapshot $emptyApps -Now $now) | Where-Object id -eq 'LOCAL.OWNER.001').pass) 'Empty inventory with empty risk policy passed'
$futureDecommission = Clone $clean
$futureDecommission.servicePrincipals[0].accountEnabled = $false
$futureDecommission.servicePrincipals[0].decommissionedAt = '2027-01-01T00:00:00Z'
Assert (-not (@(Test-PostureChecks -Snapshot $futureDecommission -Now $now) | Where-Object id -eq 'LOCAL.OWNER.003').pass) 'Future decommission date passed'
$sample = Get-Content (Join-Path $root 'fixtures/example-results.json') -Raw | ConvertFrom-Json -AsHashtable
Assert ($sample.simulated -eq $true -and $sample.illustrative -eq $true) 'Sample must be labelled illustrative and simulated'
Assert ($sample.results.Count -eq 39) 'Sample must have 39 results'
Assert ((@($sample.results.id | Sort-Object) -join ',') -ceq (@($allIds | Sort-Object) -join ',')) 'Sample IDs differ from manifest'
foreach ($check in $baseline) {
    $entry = @($sample.results | Where-Object { $_.id -ceq $check.id })
    Assert ($entry.Count -eq 1 -and $entry[0].domain -ceq $check.domain -and $entry[0].pass -eq $check.pass -and $entry[0].count -eq $check.count) "Sample differs from evaluator: $($check.id)"
}
'PASS: 39 manifest/sample IDs, 4 Pester files with 13 unique cases, 13 checks, clean control, nine negative controls'
