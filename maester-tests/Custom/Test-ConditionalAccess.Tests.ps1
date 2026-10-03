# Offline Pester cases in Agents and non-human identities; src/PostureChecks.psm1 owns evaluation.
$cases = @(
    @{ id = 'LOCAL.CA.001'; name = 'Direct excluded users must be allowlisted' }
    @{ id = 'LOCAL.CA.002'; name = 'Excluded groups must match the naming rule' }
    @{ id = 'LOCAL.CA.003'; name = 'Excluded groups need owner, review and expiry' }
)
Describe 'Agents and non-human identities — Conditional Access (supplied snapshot)' {
    BeforeAll {
        if (-not $env:POSTURE_SNAPSHOT_PATH) { throw 'Set POSTURE_SNAPSHOT_PATH to a reviewed snapshot JSON file.' }
        $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        Import-Module (Join-Path $root 'src/PostureChecks.psm1') -Force
        $snapshot = Get-Content $env:POSTURE_SNAPSHOT_PATH -Raw | ConvertFrom-Json -AsHashtable
        $clock = if ($env:POSTURE_NOW) { [datetimeoffset]::Parse($env:POSTURE_NOW, [cultureinfo]::InvariantCulture) } else { [datetimeoffset]::UtcNow }
        $results = @(Test-PostureChecks -Snapshot $snapshot -Now $clock)
    }
    It '<id> — <name>' -ForEach $cases {
        $match = @($results | Where-Object { $_.id -ceq $id })
        $match.Count | Should -Be 1
        $match[0].pass | Should -BeTrue -Because "$id reported $($match[0].count) violation(s)"
    }
}
