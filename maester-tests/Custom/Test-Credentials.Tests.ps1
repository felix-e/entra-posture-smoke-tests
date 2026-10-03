# Offline Pester cases for credentials; src/PostureChecks.psm1 owns evaluation.
$cases = @(
    @{ id = 'LOCAL.CRED.001'; name = 'Expired app credentials retained' }
    @{ id = 'LOCAL.CRED.002'; name = 'Credentials expiring within 30 days' }
    @{ id = 'LOCAL.CRED.003'; name = 'Client-secret lifetime above two calendar years' }
    @{ id = 'LOCAL.CRED.004'; name = 'Secrets without certificate or federation alternative' }
)
Describe 'Credentials (supplied snapshot)' {
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
