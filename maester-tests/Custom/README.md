# Custom tests

This directory contains four visible Pester case files for the 13 clean-room checks. All call the same [implementation module](../../src/PostureChecks.psm1); the files only select and assert its results against a **supplied JSON snapshot**. They do not retrieve tenant data or authenticate to Microsoft Graph.

| Cases | File |
| --- | --- |
| PERM (3) | [Test-Permissions.Tests.ps1](Test-Permissions.Tests.ps1) |
| OWNER (3) | [Test-Ownership.Tests.ps1](Test-Ownership.Tests.ps1) |
| CRED (4) | [Test-Credentials.Tests.ps1](Test-Credentials.Tests.ps1) |
| CA (3), within Agents and non-human identities | [Test-ConditionalAccess.Tests.ps1](Test-ConditionalAccess.Tests.ps1) |

## Getting started

- **Naming:** Keep Pester files suffixed `.Tests.ps1` so they are discoverable.
- **Local policy:** Define the risky Graph roles, approved exceptions and naming rule in the input snapshot's `config`; the synthetic example is not an organisation-wide policy.
- **Offline execution:** From the repository root, run:

```powershell
$env:POSTURE_SNAPSHOT_PATH = (Resolve-Path ./fixtures/clean-snapshot.json).Path
$env:POSTURE_NOW = '2026-01-15T00:00:00Z'
Invoke-Pester -Path ./maester-tests/Custom
```

The provided `snapshot.json` includes deliberately failing cases; use it to inspect refusal paths. `clean-snapshot.json` is the passing control. The `POSTURE_NOW` variable fixes the sample clock; omit it for a reviewed real snapshot. Do not commit a real snapshot, results, tokens or test logs to this public repo.

To run a custom directory in a separately installed and approved Maester environment, see the [Maester guidance](https://maester.dev/docs/) for `Invoke-Maester -Path`. This repo does not contain a Graph collection step or the 26 upstream test implementations. Copying these files to another suite without their module and reviewed input will not produce a meaningful result.
