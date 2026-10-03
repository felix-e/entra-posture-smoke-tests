# Maester tests

This directory contains a **local Pester adapter** for the 13 custom checks. It does not bundle Maester's upstream test library. `MaesterTags.json` at the repository root lists 26 upstream IDs and 13 custom IDs; it is a selection reference, **not** a drop-in Maester configuration file.

In a separately installed Maester suite, tests may be organised into `Custom`, `CIS`, `CISA`, `EIDSCA` and `Maester` folders. See the [official Maester tests guide](https://maester.dev/docs/tests/) for those sources and their own update instructions. This repo provides only `Custom/Test-PostureSnapshot.Tests.ps1`, which needs an operator-supplied JSON snapshot and never connects to a tenant.

## Running Maester

For this repository, start offline:

```powershell
pwsh -NoProfile -File ./tests/check-synthetic.ps1
$env:POSTURE_SNAPSHOT_PATH = (Resolve-Path ./fixtures/clean-snapshot.json).Path
$env:POSTURE_NOW = '2026-01-15T00:00:00Z'
Invoke-Pester -Path ./maester-tests/Custom/Test-PostureSnapshot.Tests.ps1
```

To run upstream Maester checks in an approved environment, install and configure Maester **separately** following [maester.dev](https://maester.dev). `Connect-Maester` and `Invoke-Maester` require real access and are not part of this synthetic demonstration. Do not run them as a publication check.

## Keeping your Maester tests up to date

The upstream project adds or changes tests over time. For a separately installed suite, `Update-Module Maester`, `Import-Module Maester` and `Update-MaesterTests` can update upstream tests. They do **not** update this reference manifest automatically. Re-check each selected ID and its meaning against the Maester version in use before adopting the list.

## Customizing severity levels

### Built-in checks

In a Maester installation, `maester-config.json` can assign `Critical`, `High`, `Medium`, `Low` or `Info` to test IDs. That config is intentionally not supplied here: a severity is an organisational decision, not a flattering default.

### Custom checks

Pester's `Severity:<level>` tag can mark a custom `Describe` or `It` block. Maester configuration can override tags where supported by the installed version. The local adapter does not assign severity; review the 13 rules and decide what failures should mean before enabling notifications.

This guidance preserves the operating intent of the original README without including its upstream snapshot, tenant configuration or run outputs. See [Custom test instructions](Custom/README.md).
