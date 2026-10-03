# MaesterTags — small, risk-led selection

`MaesterTags.json` records **39 IDs**: 26 upstream checks to obtain from Maester/CISA sources and 13 locally rewritten rules in `src/PostureChecks.psm1`. It is a reference manifest, not an upstream runner configuration. The grouping describes business questions, not independent proof of coverage. The historical two-and-a-half-minute run is not a benchmark of this clean-room repo.

## Application lifecycle and ownership (16 checks)

| ID | Why it is in the selection |
| --- | --- |
| MT.1002 | App and service-principal management restrictions |
| MT.1027 | Secrets attached to standing control-plane roles |
| MT.1038 | Conditional Access references to deleted groups |
| MT.1055 | Microsoft 365 group creation restrictions |
| MT.1068 | Tenant creation restrictions |
| MT.1069 | Security group creation restrictions |
| CISA.MS.AAD.5.1 | Admin-only application registration |
| CISA.MS.AAD.5.2 | Admin-only application consent |
| CISA.MS.AAD.5.3 | Admin-consent workflow |
| CISA.MS.AAD.5.4 | Group-owner consent restrictions |
| LOCAL.PERM.001 | Risky Graph role requests without recorded approval |
| LOCAL.PERM.002 | Multitenant apps requesting risky roles |
| LOCAL.PERM.003 | Role or Conditional Access write requests |
| LOCAL.OWNER.001 | Business owner missing on a risky app |
| LOCAL.OWNER.002 | Risky app review missing or overdue |
| LOCAL.OWNER.003 | Disabled application service principal without decommission metadata |

The first ten entries reference existing checks. The six local rules need a policy owner: what counts as risky and what constitutes recorded approval cannot be borrowed from a catalogue.

## Authentication and credentials (14 checks)

| ID | Why it is in the selection |
| --- | --- |
| CISA.MS.AAD.1.1 | Legacy-authentication block |
| CISA.MS.AAD.3.1 | Phishing-resistant MFA policy |
| CISA.MS.AAD.6.1 | Password-expiry policy |
| CISA.MS.AAD.7.4 | Standing privileged-role assignments |
| MT.1006 | Admin MFA policy |
| MT.1007 | All-user MFA policy |
| MT.1008 | Azure management MFA policy |
| MT.1009 | Other legacy-authentication block |
| MT.1010 | Exchange ActiveSync legacy-authentication block |
| MT.1052 | Device-code flow policy |
| LOCAL.CRED.001 | Expired app credentials retained |
| LOCAL.CRED.002 | Credentials expiring within 30 days |
| LOCAL.CRED.003 | Client-secret lifetime above two calendar years |
| LOCAL.CRED.004 | Secrets without certificate or federation alternative |

The local checks operate on an exported snapshot. A federated identity credential is an alternative, not a certificate with a fictitious expiry date.

## Agents and non-human identities (9 checks)

| ID | Why it is in the selection |
| --- | --- |
| MT.1003 | Policy targeting all apps |
| MT.1004 | Policy targeting all apps and users |
| MT.1005 | Emergency-account exclusions |
| MT.1020 | Sync-account scoping or exclusions |
| MT.1035 | Protection of groups used by Conditional Access |
| MT.1036 | Fallback coverage for excluded objects |
| LOCAL.CA.001 | Direct excluded users outside an explicit allowlist |
| LOCAL.CA.002 | Excluded groups outside the configured naming rule |
| LOCAL.CA.003 | Excluded groups missing owner, recent review or future expiry |

The current nine selected IDs in this intentional grouping focus on Conditional Access coverage and exclusions, including paths that may affect workloads and agents. They are not direct MCP tests. A group name is an operator cue, not evidence that its exclusion was approved.

## Deliberately outside this reference

A full catalogue run, broad user-by-user sweeps, tenant-scale extracts, upstream test source, Graph credentials, real findings and historical trend databases are not included. Direct agent/MCP posture tests would require new tests and evidence beyond this selection.

## Notes on use

Review selected IDs against the installed Maester version: tests and prerequisites change. Confirm local risk lists and expiry policy before using custom rules on real data. The supplied fixtures are synthetic. `example-results.json` contains no evaluated upstream results and must not be presented as evidence of a tenant's posture.
