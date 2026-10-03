# Custom tests

This directory contains a small Pester adapter for the 13 clean-room checks in [`src/PostureChecks.psm1`](../../src/PostureChecks.psm1). It follows the `.Tests.ps1` naming convention, but it reads a **supplied JSON snapshot**; it does not retrieve tenant data or authenticate to Microsoft Graph.

## Getting started

- **Naming:** Keep Pester files suffixed `.Tests.ps1` so they are discoverable.
- **Local policy:** Define the risky Graph roles, approved exceptions and naming rule in the input snapshot's `config`; the synthetic example is not an organisation-wide policy.
- **Offline execution:** From the repository root, run:

```powershell
$env:POSTURE_SNAPSHOT_PATH = (Resolve-Path ./fixtures/clean-snapshot.json).Path
$env:POSTURE_NOW = '2026-01-15T00:00:00Z'
Invoke-Pester -Path ./maester-tests/Custom/Test-PostureSnapshot.Tests.ps1
```

The provided `snapshot.json` includes deliberately failing cases; use it to inspect refusal paths. `clean-snapshot.json` is the passing control. The `POSTURE_NOW` variable fixes the sample clock; omit it for a reviewed real snapshot. Do not commit a real snapshot, results, tokens or test logs to this public repo.

To run a custom directory in a separately installed and approved Maester environment, see the [Maester guidance](https://maester.dev/docs/) for `Invoke-Maester -Path`. This repo does not contain a Graph collection step or the 26 upstream test implementations. Copying the adapter to another suite without its module and reviewed input will not produce a meaningful result.
