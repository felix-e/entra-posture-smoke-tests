# Offline-only Pester adapter for the 13 LOCAL checks. Never connects to a tenant.
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$manifest = Get-Content (Join-Path $root 'MaesterTags.json') -Raw | ConvertFrom-Json -AsHashtable
$cases = @($manifest.domains | ForEach-Object { $_.custom } | ForEach-Object { @{ id = $_ } })

Describe 'Local Entra posture checks (supplied snapshot)' {
    BeforeAll {
        if (-not $env:POSTURE_SNAPSHOT_PATH) { throw 'Set POSTURE_SNAPSHOT_PATH to a reviewed snapshot JSON file.' }
        $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        Import-Module (Join-Path $root 'src/PostureChecks.psm1') -Force
        $snapshot = Get-Content $env:POSTURE_SNAPSHOT_PATH -Raw | ConvertFrom-Json -AsHashtable
        $clock = if ($env:POSTURE_NOW) { [datetimeoffset]::Parse($env:POSTURE_NOW, [cultureinfo]::InvariantCulture) } else { [datetimeoffset]::UtcNow }
        $script:results = @(Test-PostureChecks -Snapshot $snapshot -Now $clock)
    }
    It '<id>' -ForEach $cases {
        $match = @($script:results | Where-Object { $_.id -ceq $id })
        $match.Count | Should -Be 1
        $match[0].pass | Should -BeTrue -Because "$id reported $($match[0].count) violation(s)"
    }
}
