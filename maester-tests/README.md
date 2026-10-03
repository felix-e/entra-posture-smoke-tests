# Maester tests

This directory contains **four local Pester files** for the 13 custom checks. Their case names are visible in GitHub; evaluation lives in the shared [PostureChecks.psm1](../src/PostureChecks.psm1) module. Empty `cis/`, `cisa/`, `EIDSCA/` and `Maester/` folders are tracked using `.gitkeep` placeholders, not upstream test files. It does not bundle Maester's upstream test library. `MaesterTags.json` at the repository root lists 26 upstream IDs and 13 custom IDs; it is a selection reference, **not** a drop-in Maester configuration file.

In a separately installed Maester suite, tests may be organised into `Custom`, `cis`, `cisa`, `EIDSCA` and `Maester` folders. See the [official Maester tests guide](https://maester.dev/docs/tests/) for those sources and their own update instructions. This repo provides [PERM](Custom/Test-Permissions.Tests.ps1), [OWNER](Custom/Test-Ownership.Tests.ps1), [CRED](Custom/Test-Credentials.Tests.ps1), and [CA](Custom/Test-ConditionalAccess.Tests.ps1) Pester files, which need an operator-supplied JSON snapshot and never connect to a tenant.

## Running Maester

For this repository, start offline:

```powershell
pwsh -NoProfile -File ./tests/check-synthetic.ps1
$env:POSTURE_SNAPSHOT_PATH = (Resolve-Path ./fixtures/clean-snapshot.json).Path
$env:POSTURE_NOW = '2026-01-15T00:00:00Z'
Invoke-Pester -Path ./maester-tests/Custom
```

To run upstream Maester checks in an approved environment, install and configure Maester **separately** following [maester.dev](https://maester.dev). `Connect-Maester` and `Invoke-Maester` require real access and are not part of this synthetic demonstration. Do not run them as a publication check.

## Keeping your Maester tests up to date

The upstream project adds or changes tests over time. For a separately installed suite, `Update-Module Maester`, `Import-Module Maester` and `Update-MaesterTests` can update upstream tests. They do **not** update this reference manifest automatically. Re-check each selected ID and its meaning against the Maester version in use before adopting the list.

## Customizing severity levels

### Built-in checks

In a Maester installation, `maester-config.json` can assign `Critical`, `High`, `Medium`, `Low` or `Info` to test IDs. That config is intentionally not supplied here: a severity is an organisational decision, not a flattering default.

### Custom checks

Pester's `Severity:<level>` tag can mark a custom `Describe` or `It` block. Maester configuration can override tags where supported by the installed version. The local Pester files do not assign severity; review the 13 rules and decide what failures should mean before enabling notifications.

This guidance preserves the operating intent of the original README without including its upstream snapshot, tenant configuration or run outputs. See [Custom test instructions](Custom/README.md).
